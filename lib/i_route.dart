import 'package:flutter/material.dart';

abstract interface class IRoute<T extends IRoute<T>> {
  String get routeName;
  // IRouteArguments getArgs(BuildContext context) => ModalRoute.of(context)!.settings.arguments as IRouteArguments;
  // IQueryArguments getQueryArgs(BuildContext context) => ModalRoute.of(context)!.settings.arguments as IQueryArguments;
}
// abstract interface class IRouteArguments<T extends IRouteArguments<T>> {

// }
// abstract interface class IQueryArguments<T extends IQueryArguments<T>> extends IRouteArguments<IQueryArguments> {
  
// }
