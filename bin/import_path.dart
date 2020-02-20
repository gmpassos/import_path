// Copyright (c) 2020, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

main(List<String> args) async {
  if (args.length != 2) {
    print('''
Expected exactly two Dart files as arguments, a file to start 
searching from and an import to search for.
''');
    return;
  }

  var from = Uri.base.resolve(args[0]);
  var importToFind = Uri.base.resolve(args[1]);
  var root =
      from.scheme == 'package' ? await Isolate.resolvePackageUri(from) : from;
  var queue = Queue<Uri>()..add(root);

  // Contains the closest parent to the root of the app for a given  uri.
  var parents = <String, String>{root.toString(): null};
  while (queue.isNotEmpty) {
    var parent = queue.removeFirst();
    var newImports = (await _importsFor(parent))
        .where((uri) => !parents.containsKey(uri.toString()));
    queue.addAll(newImports);
    for (var import in newImports) {
      parents[import.toString()] = parent.toString();
      if (importToFind == import) {
        _printImportPath(import.toString(), parents, root.toString());
        return;
      }
    }
  }
  print('Unable to find an import path from $from to $importToFind');
}

Future<List<Uri>> _importsFor(Uri uri) async {
  if (uri.scheme == 'dart') return [];

  var filePath =
      (uri.scheme == 'package' ? await Isolate.resolvePackageUri(uri) : uri)
          .toFilePath();

  var contents = File(filePath).readAsStringSync();

  var parsed = parseString(content: contents, throwIfDiagnostics: false);
  return parsed.unit.directives
      .whereType<NamespaceDirective>()
      .where((directive) {
        if (directive.uri == null) {
          print('Empty uri content: ${directive.uri}');
        }
        return directive.uri != null;
      })
      .map((directive) => uri.resolve(directive.uri.stringValue))
      .toList();
}

void _printImportPath(String import, Map<String, String> parents, String root) {
  var path = <String>[];
  var next = import;
  path.add(next);
  while (next != root && next != null) {
    next = parents[next];
    path.add(next);
  }
  var spacer = '';
  for (var import in path.reversed) {
    print('$spacer$import');
    spacer += '..';
  }
}
