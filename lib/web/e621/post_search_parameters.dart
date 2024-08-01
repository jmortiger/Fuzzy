import 'package:fuzzy/util/extensions.dart';

final class IPostSearchParameters {
  final String? tags;
  final int? limit;

  const IPostSearchParameters({
    this.tags,
    this.limit,
  });

  IPostSearchParameters copyWith({
    String? tags,
    int? limit,
  }) =>
      PostSearchParametersSlim(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
      );

  PostSearchParametersSlim get tighten => this as PostSearchParametersSlim;
}

final class PostSearchParametersSlim implements IPostSearchParameters {
  @override
  final String? tags;
  @override
  final int? limit;

  const PostSearchParametersSlim({
    this.tags,
    this.limit,
  });

  @override
  PostSearchParametersSlim copyWith({
    String? tags,
    int? limit,
  }) =>
      PostSearchParametersSlim(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
      );

  @override
  PostSearchParametersSlim get tighten => this as PostSearchParametersSlim;
}

base mixin _Auth on IPostSearchParameters {
  String? get username;
  String? get apiKey;
}

/// if [page] is used, must be a page number, not an id & modifier.
final class PostPageSearchParameters extends IPostSearchParameters
    with PageSearchParameter {
  @override
  String? get page => pageNumber?.toString();
  @override
  final int? pageNumber;

  const PostPageSearchParameters({
    super.tags,
    int? page,
    super.limit,
  }) : pageNumber = page;
  PostPageSearchParameters.fromSlim({
    PostSearchParametersSlim? s,
    int? page,
  })  : pageNumber = page,
        super(limit: s?.limit, tags: s?.tags);

  @override
  PostPageSearchParameters copyWith({
    String? tags,
    int? limit,
    int? page,
    String? username,
    String? apiKey,
  }) =>
      PostPageSearchParameters(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
        page: page?.toInt() ?? pageNumber,
      );
}

/// if [page] is used, must be a page number, not an id & modifier.
final class PostPageSearchParametersFull extends PostPageSearchParameters
    with _Auth, PageSearchParameter {
  @override
  final String? username;
  @override
  final String? apiKey;

  PostPageSearchParametersFull({
    super.tags,
    super.page,
    super.limit,
    this.username,
    this.apiKey,
  });

  @override
  PostPageSearchParametersFull copyWith({
    String? tags,
    int? limit,
    int? page,
    String? username,
    String? apiKey,
  }) =>
      PostPageSearchParametersFull(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
        page: page?.toInt() ?? pageNumber,
        username: username ?? this.username,
        apiKey: apiKey ?? this.apiKey,
      );
}

final class PostSearchParametersFull extends IPostSearchParameters
    with _Auth, PageSearchParameter {
  @override
  final String? page;
  @override
  final String? username;
  @override
  final String? apiKey;

  const PostSearchParametersFull({
    super.tags,
    this.page,
    super.limit,
    this.username,
    this.apiKey,
  });

  @override
  PostSearchParametersFull copyWith({
    String? tags,
    int? limit,
    String? page,
    String? username,
    String? apiKey,
  }) =>
      PostSearchParametersFull(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
        page: page ?? this.page,
        username: username ?? this.username,
        apiKey: apiKey ?? this.apiKey,
      );
}

mixin PageSearchParameter {
  String? get page;
  bool get hasValidPage =>
      (page?.isNotEmpty ?? false) &&
      (page!.hasOnlyNumeric ||
          ((page![0] == "a" || page![0] == "b") &&
              page!.substring(1).hasOnlyNumeric));
  bool get usesPageNumber =>
      (page?.isNotEmpty ?? false) && page!.hasOnlyNumeric;
  bool get usesPageOffset =>
      (page?.isNotEmpty ?? false) &&
      (page![0] == "a" || page![0] == "b") &&
      page!.substring(1).hasOnlyNumeric;
  String? get pageModifier => usesPageOffset ? page![0] : null;

  int? get id => usesPageOffset ? int.parse(page!.substring(1)) : null;

  int? get pageNumber => usesPageNumber ? int.parse(page!) : null;
}
mixin PageSearchParameterStrict implements PageSearchParameter {
  @override
  String get page;
  @override
  bool get hasValidPage =>
      page.isNotEmpty &&
      (page.hasOnlyNumeric ||
          ((page[0] == "a" || page[0] == "b") &&
              page.substring(1).hasOnlyNumeric));
  @override
  bool get usesPageNumber => page.isNotEmpty && page.hasOnlyNumeric;
  @override
  bool get usesPageOffset =>
      page.isNotEmpty &&
      (page[0] == "a" || page[0] == "b") &&
      page.substring(1).hasOnlyNumeric;
  @override
  String? get pageModifier => usesPageOffset ? page[0] : null;

  @override
  int? get id => usesPageOffset ? int.parse(page.substring(1)) : null;

  @override
  int? get pageNumber => usesPageNumber ? int.parse(page) : null;
}

/* abstract interface class IHasNullablePostSearchParameter<
    T extends IPostSearchParameters> {
  T? get parameter;
}

mixin ModifyPageParameter<T extends PostPageSearchParameters>
    on IHasNullablePostSearchParameter<T> {
  set pageNumber(int? value);
} */
