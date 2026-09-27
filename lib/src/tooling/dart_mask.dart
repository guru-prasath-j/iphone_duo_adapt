/// Replaces comments and string contents in Dart source with spaces, keeping
/// every other character (and every newline) in place. Offsets into the
/// result are offsets into the original, so code can be searched safely and
/// edited in the original.
///
/// Handles `//` and nested `/* */` comments, single/double quotes, triple
/// quotes, raw strings and escapes. Quote characters themselves are kept.
String maskDart(String source) {
  final out = StringBuffer();
  final n = source.length;
  var i = 0;
  String at(int k) => k < n ? source[k] : '';

  void blank(int count) {
    for (var k = 0; k < count && i < n; k++, i++) {
      out.write(source[i] == '\n' ? '\n' : ' ');
    }
  }

  while (i < n) {
    final c = source[i];
    final next = at(i + 1);

    // Line comment.
    if (c == '/' && next == '/') {
      while (i < n && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    // Block comment (Dart allows nesting).
    if (c == '/' && next == '*') {
      var depth = 0;
      do {
        if (at(i) == '/' && at(i + 1) == '*') {
          depth++;
          blank(2);
        } else if (at(i) == '*' && at(i + 1) == '/') {
          depth--;
          blank(2);
        } else {
          blank(1);
        }
      } while (i < n && depth > 0);
      continue;
    }
    // Strings.
    final raw = (c == 'r' || c == 'R') &&
        (next == "'" || next == '"') &&
        (i == 0 || !_isIdent(source[i - 1]));
    if (c == "'" || c == '"' || raw) {
      if (raw) {
        out.write(c);
        i++;
      }
      final q = source[i];
      final triple = at(i + 1) == q && at(i + 2) == q;
      final closeLen = triple ? 3 : 1;
      out.write(triple ? '$q$q$q' : q);
      i += closeLen;
      while (i < n) {
        final ch = source[i];
        if (!raw && ch == r'\') {
          blank(2);
          continue;
        }
        if (ch == q &&
            (!triple || (at(i + 1) == q && at(i + 2) == q))) {
          out.write(triple ? '$q$q$q' : q);
          i += closeLen;
          break;
        }
        if (!triple && ch == '\n') break; // Unterminated; stop at line end.
        blank(1);
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

bool _isIdent(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 48 && u <= 57) ||
      (u >= 65 && u <= 90) ||
      (u >= 97 && u <= 122) ||
      c == '_' ||
      c == r'$';
}

/// Index of the bracket that closes the one at [open] in [masked], or -1.
int matchingBracket(String masked, int open) {
  const pairs = <String, String>{'(': ')', '[': ']', '{': '}'};
  final stack = <String>[];
  for (var i = open; i < masked.length; i++) {
    final c = masked[i];
    if (pairs.containsKey(c)) {
      stack.add(pairs[c]!);
    } else if (c == ')' || c == ']' || c == '}') {
      if (stack.isEmpty || stack.removeLast() != c) return -1;
      if (stack.isEmpty) return i;
    }
  }
  return -1;
}

/// Top-level named arguments of the call whose `(` is at [open]:
/// name → offset of the name.
Map<String, int> namedArguments(String masked, int open) {
  final close = matchingBracket(masked, open);
  final result = <String, int>{};
  if (close < 0) return result;
  var depth = 0;
  var argStart = open + 1;
  for (var i = open + 1; i <= close; i++) {
    final c = masked[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if ((c == ',' && depth == 0) || i == close) {
      final arg = masked.substring(argStart, i);
      final m = RegExp(r'^\s*([A-Za-z_]\w*)\s*:').firstMatch(arg);
      if (m != null) {
        final name = m.group(1)!;
        result[name] = argStart + m.group(0)!.indexOf(name);
      }
      argStart = i + 1;
    }
  }
  return result;
}

/// 1-based line and column of [offset] in [source].
(int, int) lineColumn(String source, int offset) {
  var line = 1;
  var lineStart = 0;
  for (var i = 0; i < offset && i < source.length; i++) {
    if (source[i] == '\n') {
      line++;
      lineStart = i + 1;
    }
  }
  return (line, offset - lineStart + 1);
}
