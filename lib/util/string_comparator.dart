import 'package:string_similarity/string_similarity.dart';

/// Lower output value means lower similarity
Comparator<String> getCoarseSimilarityComparator(String mainComparison, [int resolution = 1000000,]) => (String a, String b) => (a.similarityTo(mainComparison) * resolution -
                        b.similarityTo(mainComparison) * resolution)
                    .truncate();
/// Lower output value means higher similarity
Comparator<String> getCoarseInverseSimilarityComparator(String mainComparison, [int resolution = 1000000,]) => (String a, String b) => (b.similarityTo(mainComparison) * resolution -
                        a.similarityTo(mainComparison) * resolution)
                    .truncate();
/// Lower output value means lower similarity
Comparator<String> getFineSimilarityComparator(String mainComparison) => (String a, String b) => a.similarityTo(mainComparison).compareTo(b.similarityTo(mainComparison));
/// Lower output value means higher similarity
Comparator<String> getFineInverseSimilarityComparator(String mainComparison) => (String a, String b) => b.similarityTo(mainComparison).compareTo(a.similarityTo(mainComparison));