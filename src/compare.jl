##############################################################################
##
## compare
## compare always return a value between 0 and 1.
##
##############################################################################
"""
    compare(s1::AbstractString, s2::AbstractString, dist::PreMetric)

compare returns a similarity score between the strings `s1` and `s2` based on the distance `dist`
"""

# String with Length
# This allows to compute length once and only once
struct StringWithLength{T} <: AbstractString
    s::T
    l::Int
end
string_with_length(s::AbstractString) = StringWithLength(s, length(s))
string_with_length(s::StringWithLength) = s
Base.length(s::StringWithLength) = s.l
Base.iterate(s::StringWithLength) = iterate(s.s)
Base.iterate(s::StringWithLength, i::Integer) = iterate(s.s, i)
Base.isequal(s1::StringWithLength, s2::AbstractString) = isequal(s.s1, s2)
Base.isequal(s1::AbstractString, s2::StringWithLength) = isequal(s1, s2.s)
Base.nextind(s::StringWithLength, i::Int, n::Int = 1) = nextind(s.s, i, n)
Base.ncodeunits(s::StringWithLength) = ncodeunits(s.s)
Base.isvalid(s::StringWithLength, i::Int) = isvalid(s.s, i)

function compare(s1::AbstractString, s2::AbstractString, dist::Union{Jaro, RatcliffObershelp}; min_dist = 0.0)
    1.0 - evaluate(dist, s1, s2; max_dist = 1.0 - min_dist)
end

function compare(s1::AbstractString, s2::AbstractString, 
    dist::Union{Hamming, Levenshtein, DamerauLevenshtein}; min_dist = 0.0)
    s1 = string_with_length(s1)
    s2 = string_with_length(s2)
    len = max(length(s1), length(s2))
    len == 0 && return 1.0
    max_dist = ceil(Int, len * (1 - min_dist))
    max(1.0 - evaluate(dist, s1, s2; max_dist = max_dist) / len, min_dist)
end


function compare(s1::AbstractString, s2::AbstractString, 
    dist::AbstractQGramDistance)
    # When string length < q for qgram distance, returns s1 == s2
    s1 = string_with_length(s1)
    s2 = string_with_length(s2)
    len1, len2 = length(s1), length(s2)
    min(len1, len2) <= (dist.q - 1) && return convert(Float64, s1 == s2)
    if typeof(dist) <: QGram
        1 - evaluate(dist, s1, s2) / (len1 + len2 - 2 * dist.q + 2)
    else
        1 - evaluate(dist, s1, s2)
    end
end

@deprecate compare(dist::PreMetric, s1::AbstractString, s2::AbstractString) compare(s1, s2, dist)

##############################################################################
##
## Winkler
##
##############################################################################
"""
   Winkler(dist::Premetric, scaling_factor::Real = 0.1, boosting_limit::Real = 0.7)

Winkler is a `PreMetric` modifier that boosts the similarity score between two strings by a scale `scaling_factor` when the strings share a common prefix (the boost is only applied the similarity score above `boosting_threshold`)
"""
struct Winkler{T1 <: PreMetric, T2 <: Real, T3 <: Real} <: PreMetric
    dist::T1
    scaling_factor::T2          # scaling factor. Default to 0.1
    boosting_threshold::T3      # boost threshold. Default to 0.7
end
Winkler(x) = Winkler(x, 0.1, 0.7)

function compare(s1::AbstractString, s2::AbstractString, dist::Winkler)
    score = compare(s1, s2, dist.dist)
    l = remove_prefix(s1, s2, 4)[1]
    if score >= dist.boosting_threshold
        score += l * dist.scaling_factor * (1 - score)
    end
    return score
end

JaroWinkler() = Winkler(Jaro(), 0.1, 0.7)

##############################################################################
##
## Partial
## http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/
##
##############################################################################
"""
   Partial(dist::Premetric)

Partial is a `PreMetric` modifier that returns the maximal similarity score between the shorter string and substrings of the longer string
"""
struct Partial{T <: PreMetric} <: PreMetric
    dist::T
end

function compare(s1::AbstractString, s2::AbstractString, dist::Partial)
    s1 = string_with_length(s1)
    s2 = string_with_length(s2)
    if length(s1) > length(s2)
        s2, s1 = s1, s2
    end
    len1, len2 = length(s1), length(s2)
    len1 == len2 && return compare(s1, s2, dist.dist)
    len1 == 0 && return compare("", "", dist.dist)
    out = 0.0
    for x in qgram(s2, len1)
        curr = compare(s1, x, dist.dist)
        out = max(out, curr)
    end
    return out
end

function compare(s1::AbstractString, s2::AbstractString, dist::Partial{RatcliffObershelp})
    s1 = string_with_length(s1)
    s2 = string_with_length(s2)
    if length(s1) > length(s2)
        s2, s1 = s1, s2
    end
    len1, len2 = length(s1), length(s2)
    len1 == len2 && return compare(s1, s2, dist.dist)
    out = 0.0
    for r in matching_blocks(s1, s2)
        # Make sure the substring of s2 has length len1
        s2_start = r[2] - r[1] + 1
        s2_end = s2_start + len1 - 1
        if s2_start <= 0
            s2_end += 1 - s2_start
            s2_start += 1 - s2_start
        elseif s2_end > len2
            s2_start += len2 - s2_end
            s2_end += len2 - s2_end
        end
        i2_start =  nextind(s2, 0, s2_start)
        i2_end = nextind(s2, 0, s2_end)
        curr = compare(s1, SubString(s2, i2_start, i2_end), RatcliffObershelp())
        out = max(out, curr)
    end
    return out
end

##############################################################################
##
## TokenSort
## http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/
##
##############################################################################
"""
   TokenSort(dist::Premetric)

TokenSort is a `PreMetric` modifier that adjusts for differences in word orders by reording words alphabetically.
"""
struct TokenSort{T <: PreMetric} <: PreMetric
    dist::T
end

function compare(s1::AbstractString, s2::AbstractString, dist::TokenSort)
    s1 = join(sort!(split(s1)), " ")
    s2 = join(sort!(split(s2)), " ")
    compare(s1, s2, dist.dist)
end

##############################################################################
##
## TokenSet
## http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/
##
##############################################################################
"""
   TokenSet(dist::Premetric)

TokenSort is a `PreMetric` modifier that adjusts for differences in word orders and word numbers by comparing the intersection of two strings with each string.
"""
struct TokenSet{T <: PreMetric} <: PreMetric
    dist::T
end

function compare(s1::AbstractString, s2::AbstractString, dist::TokenSet)
    v1 = SortedSet(split(s1))
    v2 = SortedSet(split(s2))
    v0 = intersect(v1, v2)
    s0 = join(v0, " ")
    s1 = join(v1, " ")
    s2 = join(v2, " ")
    isempty(s0) && return compare(s1, s2, dist.dist)
    max(compare(s0, s1, dist.dist), 
        compare(s0, s2, dist.dist),
        compare(s1, s2, dist.dist))
end


##############################################################################
##
## TokenMax
##
##############################################################################
"""
   TokenMax(dist::Premetric)

TokenSort is a `PreMetric` modifier that combines similarlity scores using the base distance, its Partial, TokenSort and TokenSet modifiers, with penalty terms depending on string lengths.
"""
struct TokenMax{T <: PreMetric} <: PreMetric
    dist::T
end

function compare(s1::AbstractString, s2::AbstractString, dist::TokenMax)
    s1 = string_with_length(s1)
    s2 = string_with_length(s2)
    if length(s1) > length(s2)
        s2, s1 = s1, s2
    end
    len1, len2 = length(s1), length(s2)
    dist0 = compare(s1, s2, dist.dist)
    unbase_scale = 0.95
    # if one string is much shorter than the other, use partial
    if length(s2) >= 1.5 * length(s1)
        partial = compare(s1, s2, Partial(dist.dist)) 
        ptsor = compare(s1, s2, TokenSort(Partial(dist.dist))) 
        ptser = compare(s1, s2, TokenSet(Partial(dist.dist))) 
        partial_scale = length(s2) > (8 * length(s1)) ? 0.6 : 0.9
        return max(dist0, 
                partial * partial_scale, 
                ptsor * unbase_scale * partial_scale, 
                ptser * unbase_scale * partial_scale)
    else
        ptsor = compare(s1, s2, TokenSort(dist.dist)) 
        ptser = compare(s1, s2, TokenSet(dist.dist)) 
        return max(dist0, 
                ptsor * unbase_scale, 
                ptser * unbase_scale)
    end
end