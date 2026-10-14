"""Wrap displayed strings with homiziText and emit the Hindi catalog."""

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
DATA_PATH = pathlib.Path(__file__).with_name('hi_pairs_data.py')
HINT_EN = (
    'English and Hindi cover the buttons, help, and messages in this app. '
    'Demo home titles follow the same language.'
)

NAMED = {
    'tooltip',
    'hintText',
    'labelText',
    'helperText',
    'semanticLabel',
    'barHintText',
    'viewHintText',
    'errorText',
}


def load_pairs():
    scope = {}
    exec(DATA_PATH.read_text(), scope)
    data = scope['PAIRS']
    pairs = []
    seen = set()
    for english, hindi in data:
        if english in seen:
            raise SystemExit(f'duplicate english: {english}')
        if '@' in hindi:
            raise SystemExit(f'hindi contains @: {english}')
        if not hindi.strip():
            raise SystemExit(f'empty hindi: {english}')
        seen.add(english)
        pairs.append((english, hindi))
    return pairs


def dart_string(value):
    return "'" + value.replace('\\', '\\\\').replace("'", r"\'").replace('$', r'\$') + "'"


def write_lookup(pairs):
    lines = [
        '// Generated from tool/hi_pairs_data.py. Edit that file, then run tool/wrap_homizi_text.py.',
        '',
        'const hiByEnglish = <String, String>{',
    ]
    for english, hindi in pairs:
        lines.append(f'  {dart_string(english)}: {dart_string(hindi)},')
    lines.append('};')
    lines.append('')
    path = ROOT / 'lib/l10n/hi_lookup.dart'
    path.write_text('\n'.join(lines))


_DART_KEYWORDS = {
    'assert', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue',
    'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
    'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
    'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
    'yield', 'async', 'hide', 'on', 'show', 'sync', 'of', 'part', 'get', 'set',
    'late', 'required', 'sealed', 'base', 'interface', 'mixin', 'when',
}


def arb_key(index, english):
    words = re.findall(r'[A-Za-z0-9]+', english)
    if not words:
        return f'm{index:03d}'
    key = words[0].lower() + ''.join(word[:1].upper() + word[1:] for word in words[1:8])
    key = re.sub(r'[^A-Za-z0-9]', '', key)
    if not key or key[0].isdigit() or key in _DART_KEYWORDS:
        key = f'm{key}'
    return key[:60]


def write_arbs(pairs):
    en = {
        '@@locale': 'en',
        'languageTitle': 'Language',
        'languageEnglish': 'English',
        'languageHindi': 'Hindi',
        'languageHint': HINT_EN,
    }
    hi = {
        '@@locale': 'hi',
        'languageTitle': 'भाषा',
        'languageEnglish': 'अंग्रेज़ी',
        'languageHindi': 'हिन्दी',
        'languageHint': 'इस ऐप के बटन, सहायता और संदेश अंग्रेज़ी और हिन्दी दोनों में हैं। डेमो घरों के शीर्षक भी उसी भाषा में रहते हैं।',
    }
    used = set(en)
    for index, (english, hindi) in enumerate(pairs, start=1):
        if english in {'Language', 'English', 'Hindi', HINT_EN}:
            continue
        key = arb_key(index, english)
        base = key
        n = 2
        while key in used:
            key = f'{base}{n}'
            n += 1
        used.add(key)
        en[key] = english
        hi[key] = hindi
    (ROOT / 'lib/l10n/app_en.arb').write_text(
        json.dumps(en, ensure_ascii=False, indent=2) + '\n'
    )
    (ROOT / 'lib/l10n/app_hi.arb').write_text(
        json.dumps(hi, ensure_ascii=False, indent=2) + '\n'
    )


def skip_file(path: pathlib.Path) -> bool:
    rel = str(path.relative_to(ROOT))
    if not rel.startswith('lib/'):
        return True
    if path.name.startswith('app_localizations'):
        return True
    if path.name in {'hi_lookup.dart', 'translate.dart'}:
        return True
    return False


def scan_string(src, i):
    quote = src[i]
    i += 1
    while i < len(src):
        ch = src[i]
        if ch == '\\':
            i += 2
            continue
        if ch == quote:
            return i + 1
        i += 1
    return i


def scan_expr_end(src, i):
    """End index of an expression that is a call argument or named value."""
    depth_paren = 0
    depth_brack = 0
    depth_brace = 0
    while i < len(src):
        ch = src[i]
        if ch in "'\"":
            i = scan_string(src, i)
            continue
        if ch == '(':
            depth_paren += 1
        elif ch == ')':
            if depth_paren == 0 and depth_brack == 0 and depth_brace == 0:
                return i
            depth_paren -= 1
        elif ch == '[':
            depth_brack += 1
        elif ch == ']':
            depth_brack -= 1
        elif ch == '{':
            depth_brace += 1
        elif ch == '}':
            depth_brace -= 1
        elif ch == ',' and depth_paren == 0 and depth_brack == 0 and depth_brace == 0:
            return i
        i += 1
    return i


def skip_ws_comments(src, i):
    while i < len(src):
        if src.startswith('//', i):
            nl = src.find('\n', i)
            i = len(src) if nl < 0 else nl + 1
            continue
        if src.startswith('/*', i):
            end = src.find('*/', i + 2)
            i = len(src) if end < 0 else end + 2
            continue
        if src[i].isspace():
            i += 1
            continue
        break
    return i


def find_call(src, i, name):
    """If src[i:] starts with name(, return index of the paren. Else None."""
    if not src.startswith(name, i):
        return None
    after = i + len(name)
    if i > 0 and (src[i - 1].isalnum() or src[i - 1] == '_'):
        return None
    j = skip_ws_comments(src, after)
    if j < len(src) and src[j] == '(':
        return j
    return None


def wrap_text(src):
    out = []
    i = 0
    changed = False
    while i < len(src):
        if src.startswith('//', i):
            nl = src.find('\n', i)
            end = len(src) if nl < 0 else nl + 1
            out.append(src[i:end])
            i = end
            continue
        if src.startswith('/*', i):
            end = src.find('*/', i + 2)
            end = len(src) if end < 0 else end + 2
            out.append(src[i:end])
            i = end
            continue
        if src[i] in "'\"":
            end = scan_string(src, i)
            out.append(src[i:end])
            i = end
            continue
        paren = find_call(src, i, 'Text')
        if paren is None:
            out.append(src[i])
            i += 1
            continue
        # Drop a preceding const that applies to this Text.
        prefix = ''.join(out)
        const_match = re.search(r'const[ \t]+$', prefix)
        if const_match and prefix[: const_match.start()].rstrip().endswith(
            ('(', '[', '{', ',', '=')
        ) or (const_match and re.search(r'(^|[\n;])\s*$', prefix[: const_match.start()])):
            if const_match:
                out = [prefix[: const_match.start()]]
        arg_start = skip_ws_comments(src, paren + 1)
        if src.startswith('homiziText(context,', arg_start):
            out.append(src[i : paren + 1])
            i = paren + 1
            continue
        arg_end = scan_expr_end(src, arg_start)
        out.append(src[i:paren + 1])
        out.append(src[paren + 1 : arg_start])
        out.append('homiziText(context, ')
        out.append(src[arg_start:arg_end])
        out.append(')')
        i = arg_end
        changed = True
    return ''.join(out), changed


def wrap_named(src):
    out = []
    i = 0
    changed = False
    names = sorted(NAMED, key=len, reverse=True)
    while i < len(src):
        if src.startswith('//', i):
            nl = src.find('\n', i)
            end = len(src) if nl < 0 else nl + 1
            out.append(src[i:end])
            i = end
            continue
        if src.startswith('/*', i):
            end = src.find('*/', i + 2)
            end = len(src) if end < 0 else end + 2
            out.append(src[i:end])
            i = end
            continue
        if src[i] in "'\"":
            end = scan_string(src, i)
            out.append(src[i:end])
            i = end
            continue
        matched = None
        for name in names:
            if src.startswith(name, i) and (
                i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_')
            ):
                j = skip_ws_comments(src, i + len(name))
                if j < len(src) and src[j] == ':':
                    matched = (name, j)
                    break
        if matched is None and src.startswith('label', i) and (
            i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_')
        ):
            j = skip_ws_comments(src, i + len('label'))
            if j < len(src) and src[j] == ':':
                value = skip_ws_comments(src, j + 1)
                if value < len(src) and src[value] in "'\"":
                    matched = ('label', j)
                else:
                    window = src[max(0, i - 240) : i]
                    if 'DropdownMenuEntry' in window:
                        matched = ('label', j)
        if matched is None and src.startswith('text', i) and (
            i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_')
        ):
            j = skip_ws_comments(src, i + len('text'))
            if j < len(src) and src[j] == ':':
                value = skip_ws_comments(src, j + 1)
                if value < len(src) and src[value] in "'\"":
                    matched = ('text', j)
        if matched is None:
            out.append(src[i])
            i += 1
            continue
        name, colon = matched
        value = skip_ws_comments(src, colon + 1)
        if src.startswith('homiziText(context,', value) or src.startswith(
            'const homiziText', value
        ):
            out.append(src[i])
            i += 1
            continue
        # Dropdown labels are strings even when they are not literals.
        if name == 'label' and not src[value] in "'\"":
            window = src[max(0, i - 240) : i]
            if 'DropdownMenuEntry' not in window:
                out.append(src[i])
                i += 1
                continue
        end = scan_expr_end(src, value)
        out.append(src[i:value])
        out.append('homiziText(context, ')
        out.append(src[value:end])
        out.append(')')
        i = end
        changed = True
    return ''.join(out), changed


def _constructor_open(src, k):
    """Index of the opening bracket for a const expression starting at k."""
    if k >= len(src):
        return None
    if src[k] in '({[':
        return k
    match = re.match(
        r'(?:[A-Za-z_][A-Za-z0-9_]*\s*)+(?:<[^>\n]*>\s*)?\(',
        src[k:],
    )
    if match:
        return k + match.end() - 1
    return None


def strip_const(src):
    changed = True
    while changed:
        changed = False
        i = 0
        while i < len(src):
            if src.startswith('//', i):
                nl = src.find('\n', i)
                i = len(src) if nl < 0 else nl + 1
                continue
            if src.startswith('/*', i):
                end = src.find('*/', i + 2)
                i = len(src) if end < 0 else end + 2
                continue
            if src[i] in "'\"":
                i = scan_string(src, i)
                continue
            if src.startswith('const', i) and (
                i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_')
            ) and (
                i + 5 >= len(src) or not (src[i + 5].isalnum() or src[i + 5] == '_')
            ):
                k = skip_ws_comments(src, i + 5)
                open_at = _constructor_open(src, k)
                if open_at is not None:
                    end = _match_open(src, open_at)
                    if 'homiziText(context' in src[open_at:end]:
                        src = src[:i] + src[k:]
                        changed = True
                        i = i
                        continue
                    i = end
                    continue
            i += 1
    return src


def _match_open(src, i):
    open_ch = src[i]
    close = { '(': ')', '[': ']', '{': '}' }[open_ch]
    depth = 0
    while i < len(src):
        ch = src[i]
        if ch in "'\"":
            i = scan_string(src, i)
            continue
        if ch == open_ch:
            depth += 1
        elif ch == close:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return i


def add_import(src):
    if 'homiziText(context' not in src:
        return src
    imp = "import 'package:homizi/core/l10n/translate.dart';"
    if imp in src:
        return src
    lines = src.splitlines(keepends=True)
    imports = []
    for index, line in enumerate(lines):
        if line.startswith('import '):
            imports.append(index)
    if not imports:
        return imp + '\n' + src
    insert_at = imports[-1] + 1
    for index in imports:
        if "package:homizi/" in lines[index] and lines[index] > imp + '\n':
            insert_at = index
            break
    lines.insert(insert_at, imp + '\n')
    return ''.join(lines)


def transform_tree():
    for path in sorted((ROOT / 'lib').rglob('*.dart')):
        if skip_file(path):
            continue
        original = path.read_text()
        src, c1 = wrap_text(original)
        src, c2 = wrap_named(src)
        stripped = strip_const(src)
        if not (c1 or c2) and stripped == original:
            continue
        src = add_import(stripped)
        path.write_text(src)
        print('wrapped', path.relative_to(ROOT))


def main():
    pairs = load_pairs()
    write_lookup(pairs)
    write_arbs(pairs)
    transform_tree()


if __name__ == '__main__':
    main()
