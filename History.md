

v0.7.0 / 2018-09-21
==================

  * Added: support for array indexing and slicing
  * Added: support for opOpAssign
  * Added: safe pure nogc dispatch
  * Added: dispatching on non optional nullable types
  * Changed: dispatch does not mutate value types
  * Changed: dispatching is automatically flattened
  * Added: covariant assignment to optional

v0.6.3 / 2018-08-27
===================

  * do not depend on a specific silly version
  * upgrade silly
  * no need for templated ctor for Dispatcher

v0.6.0 / 2018-08-24
===================

  * Don't call destroy on reference types when setting to none
  * Allow qualified optionals be used on free functions

v0.5.0 / 2018-08-16
===================

  * make dispatch return optional
  * undo double optional chaining
  * Return auto ref
  * use template this
  * Add a contruct function for objects that can't copy
  * fix copmile for @disabled copy and nested struct init
  * Add opCall
  * add in opBinary

