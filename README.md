[![Build status](https://github.com/matthieugomez/StringDistances.jl/workflows/CI/badge.svg)](https://github.com/matthieugomez/StringDistances.jl/actions)


## Installation
The package is registered in the [`General`](https://github.com/JuliaRegistries/General) registry and so can be installed at the REPL with `] add StringDistances`.

## Supported Distances

Distances are defined over iterators that define `length` (this includes `AbstractStrings`, but also `GraphemeIterators` or `AbstractVectors`)

The available distances are:

- Edit Distances
	- Hamming Distance `Hamming()`
	- [Jaro and Jaro-Winkler Distance](https://en.wikipedia.org/wiki/Jaro%E2%80%93Winkler_distance) `Jaro()` `JaroWinkler()`
	- [Levenshtein Distance](https://en.wikipedia.org/wiki/Levenshtein_distance) `Levenshtein()`
	- [Damerau-Levenshtein Distance](https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance) `DamerauLevenshtein()`
	- [Optimal String Alignement Distance](https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance) (a.k.a. restricted Damerau-Levenshtein) `OptimalStringAlignement()`
	- [RatcliffObershelp Distance](https://xlinux.nist.gov/dads/HTML/ratcliffObershelp.html) `RatcliffObershelp()`
- Q-gram distances compare the set of all substrings of length `q` in each string.
	- QGram Distance `Qgram(q::Int)`
	- [Cosine Distance](https://en.wikipedia.org/wiki/Cosine_similarity) `Cosine(q::Int)`
	- [Jaccard Distance](https://en.wikipedia.org/wiki/Jaccard_index) `Jaccard(q::Int)`
	- [Overlap Distance](https://en.wikipedia.org/wiki/Overlap_coefficient) `Overlap(q::Int)`
	- [Sorensen-Dice Distance](https://en.wikipedia.org/wiki/S%C3%B8rensen%E2%80%93Dice_coefficient) `SorensenDice(q::Int)`
	- [MorisitaOverlap Distance](https://en.wikipedia.org/wiki/Morisita%27s_overlap_index) `MorisitaOverlap(q::Int)`
	- [Normalized Multiset Distance](https://www.sciencedirect.com/science/article/pii/S1047320313001417) `NMD(q::Int)`


## Basic Use
### distance
You can always compute a certain distance between two strings using the following syntax:

```julia
evaluate(dist, s1, s2)
dist(s1, s2)
```

For instance, with the `Levenshtein` distance,

```julia
evaluate(Levenshtein(), "martha", "marhta")
Levenshtein()("martha", "marhta")
```

In contrast, the function `compare` returns the similarity score, defined as 1 minus the normalized distance between two strings. It always returns an element of type `Float64`. A value of 0.0 means completely different and a value of 1.0 means completely similar.

```julia
compare("martha", "martha", Levenshtein())
#> 1.0
```

### pairwise
`pairwise` returns the matrix of distance between two `AbstractVectors` of AbstractStrings (or iterators)

```julia
pairwise(Jaccard(3), ["martha", "kitten"], ["marhta", "sitting"])
```
The function `pairwise` is particularly optimized for QGram-distances (each element is processed only once).


### distance modifiers
The package also defines Distance "modifiers" that are defined in the Python package - [fuzzywuzzy](http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/). These modifiers are particularly helpful to match strings composed of multiple words.

- [Partial](http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/) returns the minimum of the distance between the shorter string and substrings of the longer string.
- [TokenSort](http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/) adjusts for differences in word orders by returning the distance of the two strings, after re-ordering words alphabetically. 
- [TokenSet](http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/) adjusts for differences in word orders and word numbers by returning the distance between the intersection of two strings with each string.
- [TokenMax](http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/) normalizes the distance, and combine the `Partial`, `TokenSort` and `TokenSet` modifiers, with penalty terms depending on string lengths. This is a good distance to match strings composed of multiple words, like addresses.   `TokenMax(Levenshtein())` corresponds to the distance defined in [fuzzywuzzy](http://chairnerd.seatgeek.com/fuzzywuzzy-fuzzy-string-matching-in-python/)


### find
The package also adds some convience function to find the element in a list that is closest to a given string

- `findnearest` returns the value and index of the element in `itr` with the highest similarity score with `s`. Its syntax is:
	```julia
	findnearest(s, itr, dist::StringDistance)
	```

- `findall` returns the indices of all elements in `itr` with a similarity score with `s` higher than a minimum value (default to 0.8). Its syntax is:
	```julia
	findall(s, itr, dist::StringDistance; min_score = 0.8)
	```

The functions `findnearest` and `findall` are particularly optimized for the `Levenshtein` and `OptimalStringAlignement` distances (these distances stop early if the distance is higher than a certain threshold).



