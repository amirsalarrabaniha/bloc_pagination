library bloc_pagination;

import 'package:bloc_pagination/helpers/grid_helpers.dart';
import 'package:flutter/material.dart';

typedef Widget ItemBuilder<T>(BuildContext context, T entry, int index);
typedef Future<List<T>> PageFuture<T>(int? pageIndex);
typedef Widget ErrorBuilder(BuildContext context, Object? error);
typedef Widget LoadingBuilder(BuildContext context);
typedef Widget NoItemsFoundBuilder(BuildContext context);
typedef Widget RetryBuilder(BuildContext context, RetryCallback retryCallback);
typedef void RetryCallback();
typedef Widget BlocPaginationBuilder<T>(BlocPaginationState<T> state);

/// An abstract base class for widgets that fetch their content one page at a
/// time.
///
/// The widget fetches the page when we scroll down to it, and then keeps it in
/// memory
///
/// You can build your own BlocPagination widgets by extending this class and
/// returning your builder in the [builder] function which provides you with the
/// BlocPagination state. Look [BlocPaginationListView] and [BlocPaginationGridView] for examples.
///
/// See also:
///
///  * [BlocPaginationGridView], a [BlocPagination] implementation of [GridView](https://docs.flutter.io/flutter/widgets/GridView-class.html)
///  * [BlocPaginationListView], a [BlocPagination] implementation of [ListView](https://docs.flutter.io/flutter/widgets/ListView-class.html)
abstract class BlocPagination<T> extends StatefulWidget {
  /// The number of entries per page (required when not using pageLoadController)
  final int? pageSize;

  /// ❌ Removed pageFuture completely — no fetching inside BlocPagination
  /// You are now responsible for fetching data externally
  /// and calling `appendItems()` on [BlocPaginationLoadController].

  /// Called when loading each page.
  final LoadingBuilder? loadingBuilder;

  /// Called with an error object if an error occurs when loading the page
  final ErrorBuilder? errorBuilder;

  /// Whether to show a retry button when page fails to load.
  final bool showRetry;

  /// Called when a page fails to load and [showRetry] is set to true.
  final RetryBuilder? retryBuilder;

  /// Called when no items are found
  final NoItemsFoundBuilder? noItemsFoundBuilder;

  /// Called to build each entry in the view.
  final ItemBuilder<T> itemBuilder;

  /// Builder for the main widget
  final BlocPaginationBuilder<T> builder;

  /// The controller that controls the loading of pages.
  final BlocPaginationLoadController<T>? pageLoadController;

  BlocPagination({
    this.pageSize,
    Key? key,
    this.pageLoadController,
    this.loadingBuilder,
    this.retryBuilder,
    this.noItemsFoundBuilder,
    this.showRetry = true,
    required this.itemBuilder,
    this.errorBuilder,
    required this.builder,
  }) : assert(showRetry != null),
       assert(
         // now we only check if pageLoadController is used correctly
         (pageLoadController == null && pageSize != null) ||
             (pageLoadController != null && pageSize == null),
       ),
       assert(
         showRetry == false || errorBuilder == null,
         'Cannot specify showRetry and errorBuilder at the same time',
       ),
       assert(
         showRetry == true || retryBuilder == null,
         "Cannot specify retryBuilder when showRetry is set to false",
       ),
       super(key: key);

  @override
  BlocPaginationState<T> createState() => BlocPaginationState<T>();
}

class BlocPaginationState<T> extends State<BlocPagination<T>> {
  BlocPaginationLoadController<T>? _controller;

  BlocPaginationLoadController<T>? get _effectiveController =>
      widget.pageLoadController ?? _controller;

  late VoidCallback _controllerListener;

  @override
  void initState() {
    super.initState();

    if (widget.pageLoadController == null) {
      _controller = BlocPaginationLoadController<T>(
        pageSize: widget.pageSize ?? 0,
      );
    }

    _effectiveController!.init();

    _controllerListener = () {
      setState(() {});
    };

    _effectiveController!.addListener(_controllerListener);

    // Auto fetch first page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _effectiveController!.fetchNewPage();
    });
  }

  @override
  void dispose() {
    _effectiveController!.removeListener(_controllerListener);
    super.dispose();
  }

  int get _itemCount =>
      (_effectiveController!.loadedItems?.length ?? 0) +
      (_effectiveController!.hasMoreItems ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    return widget.builder(this);
  }

  Widget _itemBuilder(BuildContext context, int index) {
    final loadedLength = _effectiveController!.loadedItems?.length ?? 0;

    if (index < loadedLength) {
      return widget.itemBuilder(
        context,
        _effectiveController!.loadedItems![index],
        index,
      );
    } else if (_effectiveController!.hasMoreItems) {
      // trigger next page automatically when loading widget is visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _effectiveController!.fetchNewPage();
      });
      return _getLoadingWidget();
    } else if (_effectiveController!.noItemsFound) {
      return _getNoItemsFoundWidget();
    } else if (_effectiveController!.error != null) {
      return widget.showRetry
          ? _getRetryWidget()
          : _getErrorWidget(_effectiveController!.error);
    } else {
      return Container();
    }
  }

  Widget _getLoadingWidget() {
    return _getStandardContainer(
      child:
          widget.loadingBuilder?.call(context) ??
          const CircularProgressIndicator(),
    );
  }

  Widget _getNoItemsFoundWidget() {
    return _getStandardContainer(
      child: widget.noItemsFoundBuilder?.call(context) ?? Container(),
    );
  }

  Widget _getErrorWidget(Object? error) {
    return _getStandardContainer(
      child:
          widget.errorBuilder?.call(context, error) ??
          Text(
            'Error: $error',
            style: TextStyle(
              color: Theme.of(context).disabledColor,
              fontStyle: FontStyle.italic,
            ),
          ),
    );
  }

  Widget _getRetryWidget() {
    return _getStandardContainer(
      child:
          widget.retryBuilder?.call(context, _effectiveController!.retry) ??
          TextButton(
            onPressed: _effectiveController!.retry,
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[300],
              shape: const CircleBorder(),
            ),
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
    );
  }

  Widget _getStandardContainer({Widget? child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(alignment: Alignment.topCenter, child: child),
    );
  }
}

/// The controller responsible for managing page loading in BlocPagination
///
/// You don't have to provide a controller yourself when creating a BlocPagination
/// widget. The widget will create one for you. However you might wish to create
/// one yourself in order to achieve some effects.
///
/// Notice though that if you provide a controller yourself, you should provide
/// the [pageFuture] and [pageSize] parameters to the *controller* instead of
/// the widget.
///
/// A possible use case of the controller is to force a reset of the loaded
/// pages using a [RefreshIndicator](https://docs.flutter.io/flutter/material/RefreshIndicator-class.html).
/// you could achieve that as follows:
///
/// ```dart
/// final _pageLoadController = BlocPaginationLoadController(
///   pageSize: 6,
///   pageFuture: BackendService.getPage
/// );
///
/// @override
/// Widget build(BuildContext context) {
///   return RefreshIndicator(
///     onRefresh: () async {
///       await this._pageLoadController.reset();
///     },
///     child: BlocPaginationListView(
///         itemBuilder: this._itemBuilder,
///         pageLoadController: this._pageLoadController,
///     ),
///   );
/// }
/// ```
///
/// Another use case for creating the controller yourself is if you want to
/// listen to the state of BlocPagination and act accordingly.
/// For example, you might want to show a specific widget when the list is empty
/// In that case, you could do:
/// ```dart
/// final _pageLoadController = BlocPaginationLoadController(
///   pageSize: 6,
///   pageFuture: BackendService.getPage
/// );
///
/// bool _empty = false;
///
/// @override
/// void initState() {
///   super.initState();
///
///   this._pageLoadController.addListener(() {
///     if (this._pageLoadController.noItemsFound) {
///       setState(() {
///         this._empty = this._pageLoadController.noItemsFound;
///       });
///     }
///   });
/// }
/// ```
///
/// And then in your `build` function you do:
/// ```dart
/// if (this._empty) {
///   return Text('NO ITEMS FOUND');
/// }
/// ```
typedef PageRequestCallback = void Function(int pageIndex);

class BlocPaginationLoadController<T> extends ChangeNotifier {
  List<T>? _loadedItems;
  late List _appendedItems;
  int _numberOfLoadedPages = 0;
  bool? _hasMoreItems;
  Object? _error;
  late bool _isFetching;

  /// We keep a callback just to signal that we need more data
  final PageRequestCallback? pageFuture;
  final int pageSize;

  BlocPaginationLoadController({required this.pageSize, this.pageFuture});

  /// Append items manually (e.g., from Bloc state)
  void appendItems(List<T> items) {
    _loadedItems ??= [];
    _loadedItems!.addAll(items);

    if (items.length < pageSize) {
      _hasMoreItems = false;
    } else {
      _hasMoreItems = true;
    }

    _numberOfLoadedPages++;
    _isFetching = false;
    notifyListeners();
  }

  void setHasMoreItems(bool value) {
    _hasMoreItems = value;
    _isFetching = false;
    notifyListeners();
  }

  List<T>? get loadedItems => _loadedItems;

  int get numberOfLoadedPages => _numberOfLoadedPages;

  bool get hasMoreItems => _hasMoreItems ?? true;

  Object? get error => _error;

  bool get noItemsFound =>
      _loadedItems != null && _loadedItems!.isEmpty && hasMoreItems == false;

  void init() {
    reset();
  }

  void reset() {
    _appendedItems = [];
    _loadedItems = [];
    _numberOfLoadedPages = 0;
    _hasMoreItems = true;
    _error = null;
    _isFetching = false;
    notifyListeners();
  }

  /// Trigger to tell external layer that a new page is requested
  Future<void> fetchNewPage() async {
    if (!_isFetching && hasMoreItems) {
      _isFetching = true;
      notifyListeners();
      pageFuture?.call(_numberOfLoadedPages); // 🔥 just notify outside
    }
  }

  void setError(Object error) {
    _error = error;
    _isFetching = false;
    notifyListeners();
  }

  void retry() {
    _error = null;
    notifyListeners();
  }

  void removeItem(bool Function(T item) test) {
    _loadedItems?.removeWhere(test);
    _isFetching = false;
    notifyListeners();
  }

  bool get isFetching => _isFetching;
}

class BlocPaginationListView<T> extends BlocPagination<T> {
  /// Creates a BlocPagination ListView.
  ///
  /// All the properties are either those documented for normal [ListViews](https://docs.flutter.io/flutter/widgets/ListView-class.html),
  /// or those inherited from [BlocPagination]
  BlocPaginationListView({
    Key? key,
    EdgeInsetsGeometry? padding,
    bool? primary,
    bool addSemanticIndexes = true,
    int? semanticChildCount,
    bool shrinkWrap = false,
    ScrollController? controller,
    BlocPaginationLoadController<T>? pageLoadController,
    double? itemExtent,
    bool addAutomaticKeepAlives = true,
    Axis scrollDirection = Axis.vertical,
    bool addRepaintBoundaries = true,
    double? cacheExtent,
    ScrollPhysics? physics,
    bool reverse = false,
    int? pageSize,
    PageFuture<T>? pageFuture,
    LoadingBuilder? loadingBuilder,
    RetryBuilder? retryBuilder,
    NoItemsFoundBuilder? noItemsFoundBuilder,
    bool showRetry = true,
    required ItemBuilder<T> itemBuilder,
    ErrorBuilder? errorBuilder,
  }) : super(
         pageSize: pageSize,
         pageLoadController: pageLoadController,
         key: key,
         loadingBuilder: loadingBuilder,
         retryBuilder: retryBuilder,
         showRetry: showRetry,
         itemBuilder: itemBuilder,
         errorBuilder: errorBuilder,
         noItemsFoundBuilder: noItemsFoundBuilder,
         builder: (BlocPaginationState<T> state) {
           return ListView.builder(
             itemExtent: itemExtent,
             addAutomaticKeepAlives: addAutomaticKeepAlives,
             scrollDirection: scrollDirection,
             addRepaintBoundaries: addRepaintBoundaries,
             cacheExtent: cacheExtent,
             physics: physics,
             reverse: reverse,
             padding: padding,
             addSemanticIndexes: addSemanticIndexes,
             semanticChildCount: semanticChildCount,
             shrinkWrap: shrinkWrap,
             primary: primary,
             controller: controller,
             itemCount: state._itemCount,
             itemBuilder: state._itemBuilder,
           );
         },
       );
}

class BlocPaginationGridView<T> extends BlocPagination<T> {
  /// Creates a BlocPagination GridView with a crossAxisCount.
  ///
  /// All the properties are either those documented for normal [GridViews](https://docs.flutter.io/flutter/widgets/GridView-class.html)
  /// or those inherited from [BlocPagination]
  BlocPaginationGridView.count({
    Key? key,
    EdgeInsetsGeometry? padding,
    required int crossAxisCount,
    double childAspectRatio = 1.0,
    double crossAxisSpacing = 0.0,
    double mainAxisSpacing = 0.0,
    bool addSemanticIndexes = true,
    int? semanticChildCount,
    bool? primary,
    bool shrinkWrap = false,
    ScrollController? controller,
    BlocPaginationLoadController<T>? pageLoadController,
    bool addAutomaticKeepAlives = true,
    Axis scrollDirection = Axis.vertical,
    bool addRepaintBoundaries = true,
    double? cacheExtent,
    ScrollPhysics? physics,
    bool reverse = false,
    int? pageSize,
    PageFuture<T>? pageFuture,
    LoadingBuilder? loadingBuilder,
    RetryBuilder? retryBuilder,
    NoItemsFoundBuilder? noItemsFoundBuilder,
    bool showRetry = true,
    required ItemBuilder<T> itemBuilder,
    ErrorBuilder? errorBuilder,
  }) : super(
         pageSize: pageSize,
         pageLoadController: pageLoadController,
         key: key,
         loadingBuilder: loadingBuilder,
         retryBuilder: retryBuilder,
         showRetry: showRetry,
         itemBuilder: itemBuilder,
         errorBuilder: errorBuilder,
         noItemsFoundBuilder: noItemsFoundBuilder,
         builder: (BlocPaginationState<T> state) {
           return GridView.builder(
             reverse: reverse,
             physics: physics,
             cacheExtent: cacheExtent,
             addRepaintBoundaries: addRepaintBoundaries,
             scrollDirection: scrollDirection,
             addAutomaticKeepAlives: addAutomaticKeepAlives,
             controller: controller,
             primary: primary,
             shrinkWrap: shrinkWrap,
             padding: padding,
             addSemanticIndexes: addSemanticIndexes,
             semanticChildCount: semanticChildCount,
             gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndLoading(
               crossAxisCount: crossAxisCount,
               childAspectRatio: childAspectRatio,
               crossAxisSpacing: crossAxisSpacing,
               mainAxisSpacing: mainAxisSpacing,
               itemCount: state._itemCount,
             ),
             itemCount: state._itemCount,
             itemBuilder: state._itemBuilder,
           );
         },
       );

  /// Creates a BlocPagination GridView with a maxCrossAxisExtent.
  ///
  /// All the properties are either those documented for normal [GridViews](https://docs.flutter.io/flutter/widgets/GridView-class.html)
  /// or those inherited from [BlocPagination]
  BlocPaginationGridView.extent({
    Key? key,
    EdgeInsetsGeometry? padding,
    required double maxCrossAxisExtent,
    double childAspectRatio = 1.0,
    double crossAxisSpacing = 0.0,
    double mainAxisSpacing = 0.0,
    bool addSemanticIndexes = true,
    int? semanticChildCount,
    bool? primary,
    bool shrinkWrap = false,
    ScrollController? controller,
    BlocPaginationLoadController<T>? pageLoadController,
    bool addAutomaticKeepAlives = true,
    Axis scrollDirection = Axis.vertical,
    bool addRepaintBoundaries = true,
    double? cacheExtent,
    ScrollPhysics? physics,
    bool reverse = false,
    int? pageSize,
    PageFuture<T>? pageFuture,
    LoadingBuilder? loadingBuilder,
    RetryBuilder? retryBuilder,
    NoItemsFoundBuilder? noItemsFoundBuilder,
    bool showRetry = true,
    required ItemBuilder<T> itemBuilder,
    ErrorBuilder? errorBuilder,
  }) : super(
         pageSize: pageSize,
         pageLoadController: pageLoadController,
         key: key,
         loadingBuilder: loadingBuilder,
         retryBuilder: retryBuilder,
         showRetry: showRetry,
         itemBuilder: itemBuilder,
         errorBuilder: errorBuilder,
         noItemsFoundBuilder: noItemsFoundBuilder,
         builder: (BlocPaginationState<T> state) {
           return GridView.builder(
             reverse: reverse,
             physics: physics,
             cacheExtent: cacheExtent,
             addRepaintBoundaries: addRepaintBoundaries,
             scrollDirection: scrollDirection,
             addAutomaticKeepAlives: addAutomaticKeepAlives,
             addSemanticIndexes: addSemanticIndexes,
             semanticChildCount: semanticChildCount,
             controller: controller,
             primary: primary,
             shrinkWrap: shrinkWrap,
             padding: padding,
             gridDelegate: SliverGridDelegateWithMaxCrossAxisExtentAndLoading(
               maxCrossAxisExtent: maxCrossAxisExtent,
               childAspectRatio: childAspectRatio,
               crossAxisSpacing: crossAxisSpacing,
               mainAxisSpacing: mainAxisSpacing,
               itemCount: state._itemCount,
             ),
             itemCount: state._itemCount,
             itemBuilder: state._itemBuilder,
           );
         },
       );
}

int _kDefaultSemanticIndexCallback(Widget _, int localIndex) => localIndex;

class BlocPaginationSliverList<T> extends BlocPagination<T> {
  /// Creates a BlocPagination SliverList.
  ///
  /// All the properties are either those documented for normal [SliverList](https://docs.flutter.io/flutter/widgets/SliverList-class.html)
  /// or those inherited from [BlocPagination]
  BlocPaginationSliverList({
    Key? key,
    bool addSemanticIndexes = true,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    SemanticIndexCallback semanticIndexCallback =
        _kDefaultSemanticIndexCallback,
    int semanticIndexOffset = 0,
    BlocPaginationLoadController<T>? pageLoadController,
    int? pageSize,
    PageFuture<T>? pageFuture,
    LoadingBuilder? loadingBuilder,
    RetryBuilder? retryBuilder,
    NoItemsFoundBuilder? noItemsFoundBuilder,
    bool showRetry = true,
    required ItemBuilder<T> itemBuilder,
    ErrorBuilder? errorBuilder,
  }) : super(
         pageSize: pageSize,
         pageLoadController: pageLoadController,
         key: key,
         loadingBuilder: loadingBuilder,
         retryBuilder: retryBuilder,
         showRetry: showRetry,
         itemBuilder: itemBuilder,
         errorBuilder: errorBuilder,
         noItemsFoundBuilder: noItemsFoundBuilder,
         builder: (BlocPaginationState<T> state) {
           return SliverList(
             delegate: SliverChildBuilderDelegate(
               state._itemBuilder,
               addAutomaticKeepAlives: addAutomaticKeepAlives,
               addRepaintBoundaries: addRepaintBoundaries,
               addSemanticIndexes: addSemanticIndexes,
               semanticIndexCallback: semanticIndexCallback,
               semanticIndexOffset: semanticIndexOffset,
               childCount: state._itemCount,
             ),
           );
         },
       );
}

class BlocPaginationSliverGrid<T> extends BlocPagination<T> {
  /// Creates a BlocPagination SliverGrid with a crossAxisCount.
  ///
  /// All the properties are either those documented for normal [SliverGrid](https://docs.flutter.io/flutter/widgets/SliverGrid-class.html)
  /// or those inherited from [BlocPagination]
  BlocPaginationSliverGrid.count({
    Key? key,
    bool addSemanticIndexes = true,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    SemanticIndexCallback semanticIndexCallback =
        _kDefaultSemanticIndexCallback,
    int semanticIndexOffset = 0,
    required int crossAxisCount,
    double childAspectRatio = 1.0,
    double crossAxisSpacing = 0.0,
    double mainAxisSpacing = 0.0,
    BlocPaginationLoadController<T>? pageLoadController,
    int? pageSize,
    PageFuture<T>? pageFuture,
    LoadingBuilder? loadingBuilder,
    RetryBuilder? retryBuilder,
    NoItemsFoundBuilder? noItemsFoundBuilder,
    bool showRetry = true,
    required ItemBuilder<T> itemBuilder,
    ErrorBuilder? errorBuilder,
  }) : super(
         pageSize: pageSize,
         pageLoadController: pageLoadController,
         key: key,
         loadingBuilder: loadingBuilder,
         retryBuilder: retryBuilder,
         showRetry: showRetry,
         itemBuilder: itemBuilder,
         errorBuilder: errorBuilder,
         noItemsFoundBuilder: noItemsFoundBuilder,
         builder: (BlocPaginationState<T> state) {
           return SliverGrid(
             delegate: SliverChildBuilderDelegate(
               state._itemBuilder,
               addAutomaticKeepAlives: addAutomaticKeepAlives,
               addRepaintBoundaries: addRepaintBoundaries,
               addSemanticIndexes: addSemanticIndexes,
               semanticIndexCallback: semanticIndexCallback,
               semanticIndexOffset: semanticIndexOffset,
               childCount: state._itemCount,
             ),
             gridDelegate: SliverGridDelegateWithFixedCrossAxisCountAndLoading(
               crossAxisCount: crossAxisCount,
               childAspectRatio: childAspectRatio,
               crossAxisSpacing: crossAxisSpacing,
               mainAxisSpacing: mainAxisSpacing,
               itemCount: state._itemCount,
             ),
           );
         },
       );

  /// Creates a BlocPagination SliverGrid with a maxCrossAxisExtent.
  ///
  /// All the properties are either those documented for normal [SliverGrid](https://docs.flutter.io/flutter/widgets/SliverGrid-class.html)
  /// or those inherited from [BlocPagination]
  BlocPaginationSliverGrid.extent({
    Key? key,
    bool addSemanticIndexes = true,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundarie = true,
    SemanticIndexCallback semanticIndexCallback =
        _kDefaultSemanticIndexCallback,
    int semanticIndexOffset = 0,
    required double maxCrossAxisExtent,
    double childAspectRatio = 1.0,
    double crossAxisSpacing = 0.0,
    double mainAxisSpacing = 0.0,
    BlocPaginationLoadController<T>? pageLoadController,
    int? pageSize,
    PageFuture<T>? pageFuture,
    LoadingBuilder? loadingBuilder,
    RetryBuilder? retryBuilder,
    NoItemsFoundBuilder? noItemsFoundBuilder,
    bool showRetry = true,
    required ItemBuilder<T> itemBuilder,
    ErrorBuilder? errorBuilder,
  }) : super(
         pageSize: pageSize,
         pageLoadController: pageLoadController,
         key: key,
         loadingBuilder: loadingBuilder,
         noItemsFoundBuilder: noItemsFoundBuilder,
         retryBuilder: retryBuilder,
         showRetry: showRetry,
         itemBuilder: itemBuilder,
         errorBuilder: errorBuilder,
         builder: (BlocPaginationState<T> state) {
           return SliverGrid(
             delegate: SliverChildBuilderDelegate(
               state._itemBuilder,
               addAutomaticKeepAlives: addAutomaticKeepAlives,
               // addRepaintBoundaries: addRepaintBoundaries,
               addSemanticIndexes: addSemanticIndexes,
               semanticIndexCallback: semanticIndexCallback,
               semanticIndexOffset: semanticIndexOffset,
               childCount: state._itemCount,
             ),
             gridDelegate: SliverGridDelegateWithMaxCrossAxisExtentAndLoading(
               maxCrossAxisExtent: maxCrossAxisExtent,
               childAspectRatio: childAspectRatio,
               crossAxisSpacing: crossAxisSpacing,
               mainAxisSpacing: mainAxisSpacing,
               itemCount: state._itemCount,
             ),
           );
         },
       );
}
