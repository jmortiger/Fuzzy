import 'package:fuzzy/util/extensions.dart';
import 'package:j_util/j_util.dart';

abstract final class IPostSearchParameters {
  String? get tags;
  Set<String>? get tagSet;
  int? get limit;
  const IPostSearchParameters();
  IPostSearchParameters copyWith({
    String? tags,
    int? limit,
  }) =>
      PostSearchParametersSlim(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
      );
}

final class PostSearchParametersSlim implements IPostSearchParameters {
  @override
  final String? tags;
  @override
  Set<String>? get tagSet =>
      tags?.split(RegExp(RegExpExt.whitespacePattern)).toSet();
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
}

base mixin _Auth on IPostSearchParameters {
  String? get username;
  String? get apiKey;
}

/// if [page] is used, must be a page number, not an id & modifier.
final class PostPageSearchParameters
    with PageSearchParameter
    implements IPostSearchParameters {
  @override
  final int? limit;
  @override
  final String? tags;
  @override
  String? get page => pageNumber?.toString();
  @override
  final int? pageNumber;
  @override
  Set<String>? get tagSet =>
      tags?.split(RegExp(RegExpExt.whitespacePattern)).toSet();

  const PostPageSearchParameters({
    this.tags,
    int? page,
    this.limit,
  }) : pageNumber = page;
  PostPageSearchParameters.fromSlim({
    PostSearchParametersSlim? s,
    int? page,
  }) : this(tags: s?.tags, limit: s?.limit, page: page);

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
  @override
  Set<String>? get tagSet =>
      tags?.split(RegExp(RegExpExt.whitespacePattern)).toSet();

  @override
  final int? limit;

  @override
  final String? tags;

  const PostSearchParametersFull({
    this.tags,
    this.page,
    this.limit,
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
bool isValidPage(String? page) =>
    (page?.isNotEmpty ?? false) &&
    (page!.hasOnlyNumeric ||
        ((page[0] == "a" || page[0] == "b") &&
            page.substring(1).hasOnlyNumeric));
bool usesPageNumber(String? page) =>
    (page?.isNotEmpty ?? false) && page!.hasOnlyNumeric;
bool usesPageOffset(String? page) =>
    (page?.isNotEmpty ?? false) &&
    (page![0] == "a" || page[0] == "b") &&
    page.substring(1).hasOnlyNumeric;
String? toPageModifier(String? page) => usesPageOffset(page) ? page![0] : null;

int? toId(String? page) =>
    usesPageOffset(page) ? int.parse(page!.substring(1)) : null;

int? toPageNumber(String? page) =>
    usesPageNumber(page) ? int.parse(page!) : null;
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
bool isValidPageStrict(String page) =>
    page.isNotEmpty &&
    (page.hasOnlyNumeric ||
        ((page[0] == "a" || page[0] == "b") &&
            page.substring(1).hasOnlyNumeric));
bool usesPageNumberStrict(String page) =>
    page.isNotEmpty && page.hasOnlyNumeric;
bool usesPageOffsetStrict(String page) =>
    page.isNotEmpty &&
    (page[0] == "a" || page[0] == "b") &&
    page.substring(1).hasOnlyNumeric;
String? toPageModifierStrict(String page) =>
    usesPageOffsetStrict(page) ? page[0] : null;

int? toIdStrict(String page) =>
    usesPageOffsetStrict(page) ? int.parse(page.substring(1)) : null;

int? toPageNumberStrict(String page) =>
    usesPageNumberStrict(page) ? int.parse(page) : null;

/* abstract interface class IHasNullablePostSearchParameter<
    T extends IPostSearchParameters> {
  T? get parameter;
}

mixin ModifyPageParameter<T extends PostPageSearchParameters>
    on IHasNullablePostSearchParameter<T> {
  set pageNumber(int? value);
} */
final class PageParameter with PageSearchParameter {
  @override
  final String? page;

  const PageParameter(this.page);
}

final class PageParameterStrict with PageSearchParameterStrict {
  @override
  final String page;

  const PageParameterStrict(this.page);
}

/// If all parameters are valid, prioritizes the page offset over page number.
String? encodePageParameterFromOptions({
  String? pageModifier,
  int? id,
  int? pageNumber,
}) =>
    (id != null && (pageModifier == 'a' || pageModifier == 'b'))
        ? "$pageModifier$id"
        : pageNumber != null
            ? "$pageNumber"
            : null;
typedef PageOffset = ({String pageModifier, int id});
typedef PageParsed = ({String? pageModifier, int? id, int? pageNumber});
dynamic parsePageParameterDirectly(String? page) => !isValidPage(page)
    ? null
    : usesPageOffsetStrict(page!)
        ? (pageModifier: toPageModifierStrict(page)!, id: toIdStrict(page)!)
        : toPageNumberStrict(page)!;
PageParsed? parsePageParameterStrict(String? page) => !isValidPage(page)
    ? null
    : (pageModifier: toPageModifierStrict(page!), id: toIdStrict(page!), pageNumber: toPageNumberStrict(page!));
PageParsed parsePageParameter(String? page) => (pageModifier: toPageModifierStrict(page!), id: toIdStrict(page!), pageNumber: toPageNumberStrict(page!));
