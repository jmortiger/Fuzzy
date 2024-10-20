import 'package:fuzzy/models/app_settings.dart';
import 'package:fuzzy/util/extensions.dart';

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
  Set<String>? get tagSet => tags?.split(RegExp(r"\s")).toSet();
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

final class PostSearchParameters
    with PageSearchParameterNullable
    implements IPostSearchParameters {
  @override
  final String? tags;
  @override
  Set<String>? get tagSet => tags?.split(RegExp(r"\s")).toSet();
  @override
  final int? limit;
  @override
  final String? page;

  const PostSearchParameters({
    this.tags,
    this.limit,
    this.page,
  });

  @override
  PostSearchParameters copyWith({
    String? tags,
    int? limit,
    String? page,
  }) =>
      PostSearchParameters(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
        page: page ?? this.page,
      );
}

final class PostSearchParametersStrict
    with PageSearchParameter
    implements IPostSearchParameters {
  @override
  final String tags;
  @override
  Set<String>? get tagSet => tags.split(RegExp(r"\s")).toSet();
  @override
  final int limit;
  @override
  final String page;

  const PostSearchParametersStrict({
    required this.tags,
    required this.limit,
    required this.page,
  });
  const PostSearchParametersStrict.withPageOffset({
    required this.tags,
    required this.limit,
    required String pageModifier,
    required int postId,
  }) : page = "$pageModifier$postId";
  PostSearchParametersStrict.fromDisparatePageParameters({
    required this.tags,
    required this.limit,
    required String? pageModifier,
    required int? postId,
    required int? pageNumber,
  }) : page = encodeValidPageParameterFromOptions(
              pageNumber: pageNumber,
              pageModifier: pageModifier,
              id: postId,
            ) ??
            "1";
  // const PostSearchParametersStrict.withDefaults({
  //   this.tags = "",
  //   required this.limit,
  //   this.page = "1",
  // });
  PostSearchParametersStrict.withDefaults({
    this.tags = "",
    int? limit,
    this.page = "1",
  }) : limit = limit ?? SearchView.i.postsPerPage;

  @override
  PostSearchParametersStrict copyWith({
    String? tags,
    int? limit,
    String? page,
  }) =>
      PostSearchParametersStrict(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
        page: page ?? this.page,
      );
}

base mixin _Auth on IPostSearchParameters {
  String? get username;
  String? get apiKey;
}

/// if [page] is used, must be a page number, not an id & modifier.
final class PageNumSearchParameters
    with PageSearchParameterNullable
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
  Set<String>? get tagSet => tags?.split(RegExp(r"\s")).toSet();

  const PageNumSearchParameters.blank({
    this.limit,
  })  : pageNumber = 0,
        tags = "";
  const PageNumSearchParameters({
    this.tags,
    int? pageIndex,
    this.limit,
  }) : pageNumber = pageIndex == null ? null : pageIndex + 1;
  const PageNumSearchParameters.withIndex({
    this.tags,
    int? pageIndex,
    this.limit,
  }) : pageNumber = pageIndex == null ? null : pageIndex + 1;
  const PageNumSearchParameters.withNumber({
    this.tags,
    this.pageNumber,
    this.limit,
  });
  PageNumSearchParameters.fromSlim({
    PostSearchParametersSlim? s,
    int? pageIndex,
  }) : this(tags: s?.tags, limit: s?.limit, pageIndex: pageIndex);

  @override
  PageNumSearchParameters copyWith({
    String? tags,
    int? limit,
    int? pageIndex,
    String? username,
    String? apiKey,
  }) =>
      PageNumSearchParameters(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
        pageIndex: pageIndex ?? pageIndex,
      );
  PageNumSearchParameterRecord toRecord() =>
      PageNumSearchParameterRecord.withNumber(
        tags: tags,
        limit: limit,
        pageNumber: pageNumber,
      );
}

final class PageNumSearchParameterRecord extends PageNumSearchParameters {
  const PageNumSearchParameterRecord({
    super.tags,
    super.pageIndex,
    super.limit,
  });
  const PageNumSearchParameterRecord.withIndex({
    super.tags,
    super.pageIndex,
    super.limit,
  });
  const PageNumSearchParameterRecord.withNumber({
    super.tags,
    super.pageNumber,
    super.limit,
  }) : super.withNumber();
  PageNumSearchParameterRecord.fromSlim({
    PostSearchParametersSlim? s,
    int? pageIndex,
  }) : this(tags: s?.tags, limit: s?.limit, pageIndex: pageIndex);
  @override
  bool operator ==(Object other) {
    return other is PageNumSearchParameterRecord &&
        limit == other.limit &&
        pageNumber == other.pageNumber &&
        tags == other.tags;
  }

  @override
  int get hashCode => Object.hash(tags, pageNumber, limit);
}

/// if [page] is used, must be a page number, not an id & modifier.
final class PageNumSearchParametersStrict extends PageNumSearchParameters {
  @override
  int get limit => super.limit!;
  @override
  String get tags => super.tags!;
  @override
  String get page => pageNumber.toString();
  @override
  int get pageNumber => super.pageNumber!;
  @override
  int get pageIndex => super.pageIndex!;
  @override
  Set<String> get tagSet => tags.split(RegExp(r"\s")).toSet();

  const PageNumSearchParametersStrict.blank({
    int super.limit = 50,
  }) : super.withNumber(pageNumber: 0, tags: "");
  const PageNumSearchParametersStrict({
    required String super.tags,
    required int pageIndex,
    required int super.limit,
  }) : super.withNumber(pageNumber: pageIndex + 1);
  const PageNumSearchParametersStrict.withIndex({
    String super.tags = "",
    int pageIndex = 0,
    required int super.limit,
  }) : super.withNumber(pageNumber: pageIndex + 1);
  const PageNumSearchParametersStrict.withNumber({
    String super.tags = "",
    int pageNumber = 1,
    required int super.limit,
  }) : super.withNumber(pageNumber: pageNumber);
  PageNumSearchParametersStrict.fromSlim({
    PostSearchParametersSlim? s,
    int pageIndex = 0,
  }) : this.withIndex(
          tags: s?.tags ?? "",
          limit: s?.limit ?? 50,
          pageIndex: pageIndex,
        );

  @override
  PageNumSearchParametersStrict copyWith({
    String? tags,
    int? limit,
    int? pageIndex,
    String? username,
    String? apiKey,
  }) =>
      PageNumSearchParametersStrict.withIndex(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
        pageIndex: pageIndex ?? this.pageIndex,
      );
  @override
  PageNumSearchParameterRecordStrict toRecord() =>
      PageNumSearchParameterRecordStrict.withNumber(
        tags: tags,
        limit: limit,
        pageNumber: pageNumber,
      );
}

final class PageNumSearchParameterRecordStrict
    extends PageNumSearchParameterRecord {
  const PageNumSearchParameterRecordStrict({
    String super.tags = "",
    int super.pageIndex = 0,
    int super.limit = 50,
  });
  const PageNumSearchParameterRecordStrict.withIndex({
    String super.tags = "",
    int super.pageIndex = 0,
    int super.limit = 50,
  });
  const PageNumSearchParameterRecordStrict.withNumber({
    String tags = "",
    int pageNumber = 1,
    int limit = 50,
  }) : super.withNumber(tags: tags, pageNumber: pageNumber, limit: limit);
  PageNumSearchParameterRecordStrict.fromSlim({
    PostSearchParametersSlim? s,
    int? pageIndex,
  }) : this(
            tags: s?.tags ?? "",
            limit: s?.limit ?? 50,
            pageIndex: pageIndex ?? 0);
  @override
  bool operator ==(Object other) {
    return other is PageNumSearchParameterRecordStrict &&
        limit == other.limit &&
        pageNumber == other.pageNumber &&
        tags == other.tags;
  }

  @override
  int get hashCode => Object.hash(tags, pageNumber, limit);
}

/// if [page] is used, must be a page number, not an id & modifier.
final class PageNumFullParameters extends PageNumSearchParameters
    with _Auth, PageSearchParameterNullable {
  @override
  final String? username;
  @override
  final String? apiKey;

  PageNumFullParameters({
    super.tags,
    super.pageIndex,
    super.limit,
    this.username,
    this.apiKey,
  });
  PageNumFullParameters.withIndex({
    super.tags,
    super.pageIndex,
    super.limit,
    this.username,
    this.apiKey,
  }) : super.withIndex();
  PageNumFullParameters.withNumber({
    super.tags,
    super.pageNumber,
    super.limit,
    this.username,
    this.apiKey,
  }) : super.withNumber();

  @override
  PageNumFullParameters copyWith({
    String? tags,
    int? limit,
    int? pageIndex,
    String? username,
    String? apiKey,
  }) =>
      PageNumFullParameters(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
        pageIndex: pageIndex?.toInt() ?? pageIndex,
        username: username ?? this.username,
        apiKey: apiKey ?? this.apiKey,
      );
}

final class PostSearchParametersFull extends IPostSearchParameters
    with _Auth, PageSearchParameterNullable {
  @override
  final String? page;
  @override
  final String? username;
  @override
  final String? apiKey;
  @override
  Set<String>? get tagSet => tags?.split(RegExp(r"\s")).toSet();

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

mixin LimitSearchParameterNullable {
  /// Exclusive. This should be a redirect to a static member. On post searches, should be 321.
  int get upperBound;
  int? get limit;

  /// Retrieves [limit] when [limit] is valid; otherwise returns a valid
  /// fallback value. This value must pass the same validation as
  /// [hasValidLimit].
  int get validLimit;
  bool get hasValidLimit => (limit ?? -1) > 0 && limit! < upperBound;
}
mixin LimitSearchParameter implements LimitSearchParameterNullable {
  @override
  int get limit;
  // @override
  // int get validLimit;
  @override
  bool get hasValidLimit => limit > 0 && limit < upperBound;
}
mixin PageSearchParameterNullable {
  String? get page;
  bool get hasValidPage =>
      (page?.isNotEmpty ?? false) &&
      (page!.hasOnlyNumeric ||
          ((page![0] == "a" || page![0] == "b") &&
              page!.substring(1).hasOnlyNumeric));
  String get validPage => isValidPage(page) ? page! : "1";
  bool get usesPageNumber =>
      (page?.isNotEmpty ?? false) && page!.hasOnlyNumeric;
  bool get usesPageOffset =>
      (page?.isNotEmpty ?? false) &&
      (page![0] == "a" || page![0] == "b") &&
      page!.substring(1).hasOnlyNumeric;
  String? get pageModifier => usesPageOffset ? page![0] : null;

  int? get id => usesPageOffset ? int.parse(page!.substring(1)) : null;

  int? get pageNumber => usesPageNumber ? int.parse(page!) : null;
  int? get pageIndex => usesPageNumber ? int.parse(page!) - 1 : null;
  String? nextValidPage([int? lastIdOnPage]) => !isValidPage(page)
      ? "2"
      : switch (getPageModifier(page)) {
          "a" => "b${getId(page)!}",
          "b" => isValidId(lastIdOnPage ?? -1) ? "b${lastIdOnPage!}" : null,
          _ => "${getPageNumber(page)! + 1}"
        };
  String? priorValidPage([int? firstIdOnPage]) => !isValidPage(page)
      ? null
      : switch (getPageModifier(page)) {
          "b" => "a${getId(page)!}",
          "a" => isValidId(firstIdOnPage ?? -1) ? "a${firstIdOnPage!}" : null,
          _ => getPageNumber(page)! > 0 ? "${getPageNumber(page)! - 1}" : null,
        };
}
bool isValidPage(String? page, {bool fullValidation = true}) =>
    (page?.isNotEmpty ?? false) &&
    (fullValidation
        ? (isValidPageNumber(int.tryParse(page!) ?? -1) ||
            ((page[0] == "a" || page[0] == "b") &&
                isValidId(int.tryParse(page.substring(1)) ?? -1)))
        : (page!.hasOnlyNumeric ||
            ((page[0] == "a" || page[0] == "b") &&
                page.substring(1).hasOnlyNumeric)));
bool isValidId(int id) => switch (id) { >= 0 => true, _ => false };
bool isValidPageNumber(int pageNumber) =>
    switch (pageNumber) { > 0 && <= 750 => true, _ => false };
bool usesPageNumber(String? page) =>
    (page?.isNotEmpty ?? false) && page!.hasOnlyNumeric;
bool usesPageOffset(String? page) =>
    (page?.isNotEmpty ?? false) &&
    (page![0] == "a" || page[0] == "b") &&
    page.substring(1).hasOnlyNumeric;
String? getPageModifier(String? page) => usesPageOffset(page) ? page![0] : null;

int? getId(String? page) =>
    usesPageOffset(page) ? int.parse(page!.substring(1)) : null;

int? getPageNumber(String? page) =>
    usesPageNumber(page) ? int.parse(page!) : null;
int? getPageIndex(String? page) =>
    usesPageNumber(page) ? int.parse(page!) - 1 : null;
mixin PageSearchParameter implements PageSearchParameterNullable {
  @override
  String get page;
  @override
  bool get hasValidPage =>
      page.isNotEmpty &&
      (page.hasOnlyNumeric ||
          ((page[0] == "a" || page[0] == "b") &&
              page.substring(1).hasOnlyNumeric));
  @override
  String get validPage => isValidPage(page) ? page : "1";
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
  @override
  int? get pageIndex => usesPageNumber ? int.parse(page) - 1 : null;
  @override
  String? nextValidPage([int? lastIdOnPage]) => !isValidPage(page)
      ? "2"
      : switch (getPageModifier(page)) {
          "a" => "b${getId(page)!}",
          "b" => isValidId(lastIdOnPage ?? -1) ? "b${lastIdOnPage!}" : null,
          _ => "${getPageNumber(page)! + 1}"
        };
  @override
  String? priorValidPage([int? firstIdOnPage]) => !isValidPage(page)
      ? null
      : switch (getPageModifier(page)) {
          "b" => "a${getId(page)!}",
          "a" => isValidId(firstIdOnPage ?? -1) ? "a${firstIdOnPage!}" : null,
          _ => getPageNumber(page)! > 0 ? "${getPageNumber(page)! - 1}" : null,
        };
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
String? getPageModifierStrict(String page) =>
    usesPageOffsetStrict(page) ? page[0] : null;

int? getIdStrict(String page) =>
    usesPageOffsetStrict(page) ? int.parse(page.substring(1)) : null;

int? getPageNumberStrict(String page) =>
    usesPageNumberStrict(page) ? int.parse(page) : null;
int? getPageIndexStrict(String page) =>
    usesPageNumberStrict(page) ? int.parse(page) - 1 : null;

/* abstract interface class IHasNullablePostSearchParameter<
    T extends IPostSearchParameters> {
  T? get parameter;
}

mixin ModifyPageParameter<T extends PostPageSearchParameters>
    on IHasNullablePostSearchParameter<T> {
  set pageNumber(int? value);
} */
mixin PageNumberParameterNullable implements PageSearchParameterNullable {
  @override
  String? get page => pageNumber?.toString();
  @override
  bool get hasValidPage => pageNumber != null && pageNumber! > 0;
  @override
  bool get usesPageNumber => hasValidPage;
  @override
  bool get usesPageOffset => false;
  @override
  String? get pageModifier => null;

  @override
  int? get id => null;

  @override
  int? get pageNumber;
  @override
  int? get pageIndex => pageNumber != null ? pageNumber! - 1 : null;
}

final class PageParameter with PageSearchParameterNullable {
  @override
  final String? page;

  const PageParameter(this.page);
}

final class PageParameterStrict with PageSearchParameter {
  @override
  final String page;

  const PageParameterStrict(this.page);
}

/// If all parameters are valid, prioritizes the page offset over page number over page index.
String? encodePageParameterFromOptions({
  String? pageModifier,
  int? id,
  int? pageNumber,
  int? pageIndex,
}) =>
    (id != null && (pageModifier == 'a' || pageModifier == 'b'))
        ? "$pageModifier$id"
        : pageNumber != null
            ? "$pageNumber"
            : pageIndex != null
                ? "${pageIndex + 1}"
                : null;
String? encodeValidPageParameterFromOptions({
  String? pageModifier,
  int? id,
  int? pageNumber,
  int? pageIndex,
}) =>
    (id != null && id > -1 && (pageModifier == 'a' || pageModifier == 'b'))
        ? "$pageModifier$id"
        : pageNumber != null && pageNumber > 0
            ? "$pageNumber"
            : pageIndex != null && pageIndex > -1
                ? "${pageIndex + 1}"
                : null;
typedef PageOffset = ({String pageModifier, int id});
typedef PageParsed = ({String? pageModifier, int? id, int? pageNumber});
dynamic parsePageParameterDirectly(String? page) => !isValidPage(page)
    ? null
    : usesPageOffsetStrict(page!)
        ? (pageModifier: getPageModifierStrict(page)!, id: getIdStrict(page)!)
        : getPageNumberStrict(page)!;
PageParsed? parsePageParameterStrict(String? page) =>
    page == null || !isValidPage(page)
        ? null
        : (
            pageModifier: getPageModifierStrict(page),
            id: getIdStrict(page),
            pageNumber: getPageNumberStrict(page)
          );
PageParsed parsePageParameter(String? page) => (
      pageModifier: getPageModifier(page),
      id: getId(page),
      pageNumber: getPageNumber(page)
    );

mixin SearchParametersNullable
    on PageSearchParameterNullable, LimitSearchParameterNullable {}
mixin SearchParameters on PageSearchParameter, LimitSearchParameter {}

class PostSearchQueryRecordSlimNullable
    implements ComparableRecord<PostSearchQueryRecordSlimNullable> {
  final String? tags;
  Set<String>? get tagSet => tags?.split(RegExp(r"\s")).toSet();
  const PostSearchQueryRecordSlimNullable(this.tags);

  @override
  PostSearchQueryRecordSlimNullable copyWith({String? tags = "\u{7}"}) =>
      PostSearchQueryRecordSlimNullable(tags == "\u{7}" ? this.tags : tags);

  @override
  bool operator ==(Object other) {
    return other is PostSearchQueryRecordSlimNullable && tags == other.tags;
  }

  @override
  int get hashCode => Object.hash(tags, 21);
}

class PostSearchQueryRecordSlim implements PostSearchQueryRecordSlimNullable {
  @override
  final String tags;
  @override
  Set<String> get tagSet => tags.split(RegExp(r"\s")).toSet();
  const PostSearchQueryRecordSlim(this.tags);

  @override
  PostSearchQueryRecordSlimNullable copyWith({String? tags}) =>
      PostSearchQueryRecordSlimNullable(tags ?? this.tags);

  @override
  bool operator ==(Object other) {
    return other is PostSearchQueryRecordSlim && tags == other.tags;
  }

  @override
  int get hashCode => Object.hash(tags, 21);
}

class PostSearchQueryRecordNullable
    with
        PageSearchParameterNullable,
        LimitSearchParameterNullable
    implements
        /* ComparableRecord<PostSearchQueryRecordNullable>, */
        PostSearchQueryRecordSlimNullable {
  @override
  final String? tags;
  @override
  Set<String>? get tagSet => tags?.split(RegExp(r"\s")).toSet();
  @override
  final int? limit;

  @override
  final String? page;

  @override
  int get upperBound => 320;

  @override
  int get validLimit => hasValidLimit ? limit! : SearchView.i.postsPerPage;
  const PostSearchQueryRecordNullable({
    this.tags,
    this.limit,
    this.page,
  });

  @override
  PostSearchQueryRecordNullable copyWith({
    String? tags = "\u{7}",
    int? limit = -1,
    String? page = "\u{7}",
    int? pageNumber = -1,
    int? pageIndex = -1,
    int? postId = -1,
    String? pageModifier = "\u{7}",
  }) =>
      PostSearchQueryRecordNullable(
        tags: tags == "\u{7}" ? this.tags : tags,
        limit: limit != null && limit > 0 ? this.limit : limit,
        page: page == "\u{7}"
            ? encodeValidPageParameterFromOptions(
                  id: postId,
                  pageIndex: pageIndex,
                  pageModifier: pageModifier,
                  pageNumber: pageNumber,
                ) ??
                this.page
            : page,
      );

  @override
  bool operator ==(Object other) {
    return other is PostSearchQueryRecordNullable &&
        tags == other.tags &&
        limit == other.limit &&
        page == other.page;
  }

  bool isSameSearch(Object other) =>
      other is PostSearchQueryRecordNullable &&
      tags == other.tags &&
      limit == other.limit;

  bool hasGreaterPageNumber(PostSearchQueryRecordNullable other,
          {bool orEqual = false}) =>
      tags == other.tags &&
      limit == other.limit &&
      pageNumber != null &&
      other.pageNumber != null &&
      (pageNumber! > other.pageNumber! ||
          (orEqual && pageNumber! == other.pageNumber!));
  bool hasLesserPageNumber(PostSearchQueryRecordNullable other,
          {bool orEqual = false}) =>
      tags == other.tags &&
      limit == other.limit &&
      pageNumber != null &&
      other.pageNumber != null &&
      (pageNumber! < other.pageNumber! ||
          (orEqual && pageNumber! == other.pageNumber!));

  @override
  int get hashCode => Object.hash(tags, limit, page);
}

class PostSearchQueryRecord extends PostSearchQueryRecordNullable {
  @override
  String get tags => super.tags!;

  @override
  int get limit => super.limit!;

  @override
  String get page => super.page!;

  @override
  int get upperBound => 320;
  const PostSearchQueryRecord({
    String super.tags = "",
    int super.limit = -1,
    String super.page = "1",
  });
  const PostSearchQueryRecord.withIndex({
    String tags = "",
    int limit = -1,
    int pageIndex = 0,
  }) : super(limit: limit, tags: tags, page: "${pageIndex + 1}");
  const PostSearchQueryRecord.withNumber({
    String tags = "",
    int limit = -1,
    int pageNumber = 1,
  }) : super(limit: limit, tags: tags, page: "$pageNumber");

  @override
  PostSearchQueryRecord copyWith({
    String? tags,
    int? limit,
    String? page,
    int? pageNumber,
    int? pageIndex,
    int? postId,
    String? pageModifier,
  }) =>
      PostSearchQueryRecord(
        tags: tags ?? this.tags,
        limit: limit ?? this.limit,
        page: page ??
            encodeValidPageParameterFromOptions(
              id: postId,
              pageIndex: pageIndex,
              pageModifier: pageModifier,
              pageNumber: pageNumber,
            ) ??
            this.page,
      );

  @override
  bool operator ==(Object other) {
    return other is PostSearchQueryRecord &&
        tags == other.tags &&
        limit == other.limit &&
        page == other.page;
  }

  @override
  int get hashCode => Object.hash(tags, limit, page);

  @override
  String toString() {
    return "{ tags: $tags, limit: $limit, page: $page }";
  }
}

abstract interface class ComparableRecord<T extends ComparableRecord<T>> {
  T copyWith();

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

enum PageModifier {
  after("a"),
  before("b");

  static const prior = after;
  static const next = before;

  final String query;
  const PageModifier(this.query);
}
