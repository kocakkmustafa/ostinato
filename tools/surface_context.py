"""Small, fail-closed context readers for the surface gate, not Dart evaluation.

Unrecognised expressions retain the default locale/unknown-hand checks. Context
only classifies a string for one rule; every honesty rule still sees its text.
"""
import re

LITERAL = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"")


def _string(source, start):
    """Read a Dart string, recursively separating interpolation expressions."""
    quote, i, text, nested = source[start], start + 1, '', []
    raw = start > 0 and source[start - 1] == 'r' and (
        start < 2 or not source[start - 2].isalnum())
    while i < len(source):
        if source[i] == quote:
            return i + 1, text, nested
        if source[i] == '\\' and not raw:
            text += source[i:i + 2]
            i += 2
            continue
        if not raw and source.startswith('${', i):
            depth, i = 1, i + 2
            while i < len(source) and depth:
                if source[i] in "'\"":
                    end, value, children = _string(source, i)
                    nested.append((i, end, value))
                    nested += children
                    i = end
                    continue
                if source[i] == '{':
                    depth += 1
                elif source[i] == '}':
                    depth -= 1
                i += 1
            text += '${...}'
            continue
        text += source[i]
        i += 1
    return len(source), text, nested


def dart_literals(source):
    tokens, i = [], 0
    while i < len(source):
        if source[i] in "'\"":
            end, value, nested = _string(source, i)
            tokens.append((i, end, value))
            tokens += nested
            i = end
        else:
            i += 1
    return sorted(tokens)


def merged_dart_literals(source):
    # Merge siblings at each interpolation depth separately. An inner literal
    # must not overwrite its outer string's end before adjacent concatenation.
    groups, stack = {}, []
    for index, token in enumerate(dart_literals(source)):
        left, right, _ = token
        while stack and stack[-1][1] <= left:
            stack.pop()
        parent = stack[-1][0] if stack else None
        groups.setdefault(parent, []).append(token)
        stack.append((index, right))
    merged = []
    for tokens in groups.values():
        pending, start, end = None, None, None
        for left, right, value in tokens:
            if pending is not None and end <= left and not source[end:left].strip():
                pending += value
            else:
                if pending is not None:
                    merged.append((start, end, pending))
                pending, start = value, left
            end = right
        if pending is not None:
            merged.append((start, end, pending))
    yield from sorted(merged)


def arguments(source, opening):
    """Return top-level argument spans in one balanced call/list/map."""
    pairs = {'(': ')', '[': ']', '{': '}'}
    stack = [pairs[source[opening]]]
    spans, start, i = [], opening + 1, opening + 1
    while i < len(source):
        if source[i] in "'\"":
            i = _string(source, i)[0]
            continue
        char = source[i]
        if char in pairs:
            stack.append(pairs[char])
        elif char in ')]}':
            if char != stack.pop():
                return []
            if not stack:
                if source[start:i].strip():
                    spans.append((start, i))
                return spans
        elif char == ',' and len(stack) == 1:
            spans.append((start, i))
            start = i + 1
        i += 1
    return []


_NAMED_ARGUMENT = re.compile(r'\s*(\w+)\s*:(?!:)')


def pair_ranges(source, name, turkish_index, arity=None, named=()):
    """Positional EN/TR pair arguments; `named` lists the only trailing
    named arguments the proven dispatcher accepts (values, pluralCount)."""
    ranges = []
    positional = arity or turkish_index + 1
    for match in re.finditer(r'\b' + re.escape(name) + r'\s*\(', source):
        # A method with the same spelling is not the imported dispatcher.
        if source[:match.start()].rstrip().endswith('.'):
            continue
        args = arguments(source, source.index('(', match.start()))
        if len(args) < positional:
            continue
        head, extra = args[:positional], args[positional:]
        if any(_NAMED_ARGUMENT.match(source[a:b]) for a, b in head):
            continue
        names = [_NAMED_ARGUMENT.match(source[a:b]) for a, b in extra]
        if all(m and m[1] in named for m in names) and (
                len({m[1] for m in names}) == len(names)):
            ranges.append(args[turkish_index])
    return ranges


LOCALE_DISPATCHER = (
    r"String localized\(BuildContext context, String english, String turkish\)\s*=>\s*"
    r"Localizations\.localeOf\(context\)\.languageCode == 'tr' \? turkish : english;")

# Fourteen-locale dispatcher (2026-10-20): the pair is forwarded verbatim to
# `AppTranslations.text`. It is accepted only together with
# [translation_text_proof] over app_translation_catalog.dart.
TRANSLATION_DISPATCHER = (
    r"String localized\(\s*BuildContext context,\s*String english,\s*String turkish,\s*"
    r"\{\s*Map<String, Object\?> values = const \{\},\s*num\? pluralCount,?\s*\}\s*\)\s*=>\s*"
    r"\(\s*AppTranslations\.maybeOf\(context\)\s*\?\?\s*AppTranslations\(\s*"
    r"Localizations\.maybeLocaleOf\(context\)\s*\?\?\s*const Locale\('en'\),\s*"
    r"const \{\},?\s*\)\s*\)\s*"
    r"\.text\(english, turkish, values: values, pluralCount: pluralCount\);")
LOCALIZED_NAMED = ('values', 'pluralCount')

_TEXT_SIGNATURE = re.compile(
    r"String text\(\s*String english,\s*String turkish,\s*\{\s*"
    r"Map<String, Object\?> values = const \{\},\s*num\? pluralCount,?\s*\}\s*\)\s*\{")
_TR_BRANCH = re.compile(r"tag == 'tr' \? turkish : english")
_KEY_LOOKUP = re.compile(r"appMessageIds\[\(english, turkish\)\]")
_PLURAL_LOOKUP = re.compile(
    r"appMessagePluralSources\[id\]\?\[tag == 'tr' \? 'trOne' : 'enOne'\]")


def translation_text_proof(catalog_source, lib_sources=None):
    """True only when `turkish` can reach a rendered template solely on the
    `tag == 'tr'` branch of the one `AppTranslations.text` method.

    The TR argument may also be read as half of the message-ID lookup key;
    that key selects a catalog entry for the device locale and is never
    rendered itself. Any other use of `turkish`, a reassigned `tag`, a second
    `text` method or another reader of the ID/plural maps fails closed.
    """
    signatures = list(_TEXT_SIGNATURE.finditer(catalog_source))
    if len(signatures) != 1:
        return False
    opening = signatures[0].end() - 1
    spans = arguments(catalog_source, opening)
    if not spans:
        return False
    body = catalog_source[opening:spans[-1][1] + 1]
    outside = catalog_source[:signatures[0].start()] + catalog_source[opening + len(body):]
    if re.search(r'\bturkish\b', outside):
        return False
    if len(re.findall(r'\bfinal tag = canonicalLanguageTag\(locale\);', body)) != 1:
        return False
    if len(re.findall(r'\btag\s*(?:[-+*/|&^]|\?\?)?=(?!=)', body)) != 1:
        return False
    allowed = [m.span() for m in _TR_BRANCH.finditer(body)]
    allowed += [m.span() for m in _KEY_LOOKUP.finditer(body)]
    if len(list(_KEY_LOOKUP.finditer(body))) != 1 or not _TR_BRANCH.search(body):
        return False
    for match in re.finditer(r'\bturkish\b', body):
        if not any(a <= match.start() < b for a, b in allowed):
            return False
    plural = [m.span() for m in _PLURAL_LOOKUP.finditer(body)]
    for match in re.finditer(r"'trOne'", catalog_source):
        if not any(a <= match.start() - opening < b for a, b in plural):
            return False
    if lib_sources is not None:
        readers = []
        for file, source in lib_sources.items():
            if file == 'lib/app/app_message_ids.dart':
                continue
            readers += [(file, m.start()) for m in re.finditer(
                r'\bappMessage(?:Ids|PluralSources)\b', source)]
        expected = len(_KEY_LOOKUP.findall(body)) + len(_PLURAL_LOOKUP.findall(body)) + len(
            re.findall(r'\bappMessagePluralSources\.containsKey\(entry\.key\)', catalog_source))
        if any(f != 'lib/app/app_translation_catalog.dart' for f, _ in readers) or (
                len(readers) != expected):
            return False
    return True


def _dispatcher_shadowed(source, trusted_definition=False):
    # The imported name may resolve to a local/member callable instead. Such
    # a file retains language checks rather than guessing Dart name resolution.
    if trusted_definition:
        source = re.sub(LOCALE_DISPATCHER, '', source, count=1)
        source = re.sub(TRANSLATION_DISPATCHER, '', source, count=1)
    if re.search(r'\blocalized\s*(?:=(?!=)|=>)|'
                 r'\b(?:final|var|Function|dynamic|String|Object)[?]?\s+localized\b', source):
        return True
    for match in re.finditer(r'\blocalized\s*\(', source):
        opening = source.index('(', match.start())
        args = arguments(source, opening)
        if args:
            closing = source.find(')', args[-1][1])
            if re.match(r'\s*(?:=>|\{)', source[closing + 1:]):
                return True
    # Untyped closure parameters can also shadow the imported name.
    return bool(re.search(r'\([^()]*\blocalized\b[^()]*\)\s*(?:=>|\{)', source))


def paired_json_contexts(node, path):
    locales, invalid = {}, []

    def walk(value, where):
        if isinstance(value, dict):
            if 'en' in value or 'tr' in value:
                if (set(value) == {'en', 'tr'} and
                        all(isinstance(v, str) and v.strip()
                            for v in value.values())):
                    locales.update({f'{where}.{key}': key for key in value})
                else:
                    invalid.append(where)
            for key, child in value.items():
                if not key.startswith(('_', '$')):
                    walk(child, f'{where}.{key}')
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, f'{where}[{index}]')

    walk(node, path)
    return locales, invalid


def hand_context(node):
    """A keyboard has fixed hand roles; strings need an explicit convention."""
    instrument = node.get('id', '').split('.')[0]
    if instrument == 'piano':
        return 'keyboard_hands'
    entry = node.get('entry', {})
    if instrument in {'guitar', 'ukulele', 'bass'} and isinstance(entry, dict):
        for sentence in re.split(r'[.!?]', entry.get('en', '')):
            if (re.match(r'\s*(?:right|left)-handed\b', sentence, re.I) and
                    not re.search(r'\b(?:not|never|no|without)\b', sentence, re.I)):
                return 'declared_string_convention'
    return None


def body_side_allowed(context, matched):
    if context not in {'declared_string_convention', 'keyboard_hands'}:
        return False
    limbs = (r'\b(?:hands?|thumb|fingers?|wrists?)\b|'
             r'\b(?:el(?:in|ini|ler)?|başparmak|işaret|orta parmak|bilek)\b')
    return bool(re.search(limbs, matched, re.I))


def historical_body_report(sentence):
    return bool(re.search(
        r'Kaydedilmiş referans analizinde[^.!?]*kayıtlarda[^.!?]*'
        r'güvenilir biçimde ayrılmadı', sentence, re.I)) and not re.search(
            r'\byour\b|\b(?:keep|raise|place|hold|elini|kolunu|kaldır|yerleştir|tut)\b',
            sentence, re.I)


def dart_hand_context(source, json_contexts):
    # Diagram widgets are linked to the actual course convention, not to a
    # per-string exclusion. Changing that convention removes the allowance.
    if (json_contexts.get('assets/content/piano_beginner.v1.json') == 'keyboard_hands'
            and re.search(r'class PianoVisualPracticeScreen\b', source)
            and "import 'piano_notation.dart'" in source
            and 'pianoStudyRight' in source and 'pianoStudyLeft' in source):
        return 'keyboard_hands'
    if (json_contexts.get('assets/content/ukulele_beginner.v1.json') ==
            'declared_string_convention' and
            re.search(r'class UkuleleDiagrams\b', source) and
            'UkuleleCourse course' in source and
            re.search(r"import ['\"][^'\"]*ukulele_beginner.dart['\"]", source)):
        return 'declared_string_convention'
    return None


def instructional_promise_word(sentence, label):
    """A present physical instruction or spatial 'nearby' is not a roadmap."""
    if label == 'yet':
        safe = re.compile(
            r'\bno (?:sustain )?pedal yet\b|'
            r'\bdo not (?:play|strum|sing|press|pluck)\b[^.!?;]*?\byet\b', re.I)
    elif label == 'henüz':
        safe = re.compile(r'\bhenüz (?:çalma|söyleme|basma|çekme|kullanma)\b', re.I)
    elif label == 'yakında':
        safe = re.compile(r'\byakında su (?:olabilir|bulundur)\b', re.I)
    else:
        return False
    ranges = [match.span() for match in safe.finditer(sentence)]
    words = list(re.finditer(r'\b' + re.escape(label) + r'\b', sentence, re.I))
    return bool(words) and all(any(a <= match.start() < b for a, b in ranges)
                               for match in words)


def without_labelled_turkish_quote(text):
    return re.sub(r'\bTurkish\s+[“"][^”"]+[”"]', 'Turkish example', text)


def _condition_start(source, start):
    before = source[:start].rstrip()
    if not before or before[-1] in '(,:{[' or re.search(r'\breturn$', before):
        return True
    if before.endswith('=>'):
        return True
    return before.endswith('=') and not before.endswith(('==', '!=', '<=', '>='))


def _expression_end(source, start):
    depth, i = 0, start
    while i < len(source):
        if source[i] in "'\"":
            i = _string(source, i)[0]
            continue
        if source[i] in '([{':
            depth += 1
        elif source[i] in ')]}':
            depth -= 1
        elif source[i] == ';' and depth == 0:
            return i
        i += 1
    return len(source)


def _block(source, position):
    stack, i = [], 0
    while i < position:
        if source[i] in "'\"":
            i = _string(source, i)[0]
            continue
        if source[i] == '{':
            stack.append(i)
        elif source[i] == '}' and stack:
            stack.pop()
        i += 1
    if not stack:
        return 0, len(source)
    opening = stack[-1]
    spans = arguments(source, opening)
    return opening, spans[-1][1] + 1 if spans else position


def _locale_bindings(source, predicate):
    bindings = []
    for match in re.finditer(
            r'\b(final|var|bool)\s+(?:bool\s+)?(\w+)\s*=\s*([^;]+);', source):
        left, right = _block(source, match.start())
        proven = match[1] == 'final' and bool(re.fullmatch(
            predicate + r"|widget\.locale\s*==\s*'tr'", match[3].strip()))
        bindings.append([match[2], left, right, match.start(), proven])
    functions = []
    for match in re.finditer(r'\(', source):
        opening = match.start()
        prefix = re.search(r'(\w+)\s*$', source[:opening])
        name = prefix[1] if prefix else None
        if name in {'if', 'while', 'switch', 'for', 'catch', 'assert'}:
            continue
        args = arguments(source, opening)
        if not args:
            continue
        closing = source.find(')', args[-1][1])
        after = re.match(r'\s*(\{|=>)', source[closing + 1:])
        if not after:
            continue
        if after[1] == '{':
            body = closing + 1 + after.end() - 1
            contents = arguments(source, body)
            if not contents:
                continue
            body_end = contents[-1][1] + 1
        else:
            body = closing + 1 + after.end()
            body_end = _expression_end(source, body)
        parameters = []
        for index, (a, b) in enumerate(args):
            raw = source[a:b].strip()
            if raw.startswith(('{', '[')):
                start = a + len(source[a:b]) - len(source[a:b].lstrip())
                parameters += [(left, right, None) for left, right
                               in arguments(source, start)]
            else:
                parameters.append((a, b, index))
        for a, b, index in parameters:
            raw = source[a:b].split('=', 1)[0].strip()
            parameter = re.fullmatch(
                r'(?:(?:required|covariant)\s+)?(?:(?:\w+[?]?)\s+)?(\w+)', raw)
            if parameter:
                binding = [parameter[1], body, body_end, body, False]
                bindings.append(binding)
                if name and index is not None and re.fullmatch(r'bool\s+\w+', raw):
                    functions.append((name, opening, index, len(args), binding))

    # A loop header can introduce typed, untyped or pattern bindings. If it
    # mentions a candidate locale name, conservatively stop proving that name
    # for the remainder of its enclosing block, including collection-for UI.
    for match in re.finditer(r'\bfor\s*\(', source):
        opening = source.index('(', match.start())
        args = arguments(source, opening)
        if not args:
            continue
        header_end = source.find(')', args[-1][1])
        left, right = _block(source, match.start())
        for name in {binding[0] for binding in bindings}:
            if re.search(r'\b' + re.escape(name) + r'\b', source[opening:header_end]):
                bindings.append([name, left, right, match.start(), False])

    def known(name, position):
        candidates = [b for b in bindings
                      if b[0] == name and b[1] <= position < b[2] and b[3] < position]
        return bool(candidates) and max(candidates, key=lambda b: (b[1], b[3]))[4]

    # Private positional helpers can forward a proven locale flag, only if
    # every call site does so. Exported/unknown/mutable flags remain unchecked.
    for name, declaration, index, arity, binding in functions:
        if not name.startswith('_') or re.search(
                r'\b' + binding[0] + r'\s*(?:[|&^]|\?\?)?=(?!=)',
                source[binding[1]:binding[2]]):
            continue
        calls, call_positions = [], set()
        for match in re.finditer(r'\b' + re.escape(name) + r'\s*\(', source):
            opening = source.index('(', match.start())
            if opening == declaration:
                call_positions.add(match.start())
                continue
            call_positions.add(match.start())
            args = arguments(source, opening)
            calls.append(len(args) == arity and known(
                source[slice(*args[index])].strip(), match.start()))
        references = {match.start() for match in re.finditer(
            r'\b' + re.escape(name) + r'\b', source)}
        binding[4] = bool(calls) and all(calls) and references <= call_positions
    return known, {b[0] for b in bindings}


def dart_turkish_ranges(source, *, localized_guard, study_guard=False,
                        reviewed_guard=False, trusted_dispatcher_definition=False):
    """Recognise dispatch arguments, not an entire file importing a helper."""
    ranges = []
    localized_guard = localized_guard and not _dispatcher_shadowed(
        source, trusted_dispatcher_definition)
    if localized_guard:
        ranges += pair_ranges(source, 'localized', 2, named=LOCALIZED_NAMED)
        # Local wrappers must forward the exact English and Turkish arguments.
        wrapper = re.compile(
            r'\b(\w+)\s*\(\s*BuildContext context,\s*String (\w+),\s*'
            r'String (\w+),?\s*\)\s*=>\s*localized\(context,\s*\2,\s*\3\)\s*;')
        for match in wrapper.finditer(source):
            ranges += pair_ranges(source, match.group(1), 2)
        section = re.compile(
            r'\b(\w+)\(BuildContext context, String (\w+), String (\w+), '
            r'String \w+\)\s*=>')
        for match in section.finditer(source):
            body = source[match.end():_expression_end(source, match.end())]
            dispatch = re.compile(r'localized\(context,\s*' + match[2] +
                                  r',\s*' + match[3] + r'\)')
            if dispatch.search(body) and not re.search(
                    r'\b' + match[3] + r'\b', dispatch.sub('', body)):
                ranges += pair_ranges(source, match[1], 2, arity=4)
    if study_guard:
        ranges += pair_ranges(source, 'StudyText', 1)
    if reviewed_guard:
        ranges += pair_ranges(source, '_Reviewed', 1)

    # Literal/list true branches are TR only with an actual locale predicate.
    predicate = r"Localizations\.localeOf\(context\)\.languageCode\s*==\s*'tr'"
    known, variables = _locale_bindings(source, predicate)
    predicates = [predicate] + [r'\b' + re.escape(name) + r'\b' for name in variables]
    for match in re.finditer(r'if\s*\(\s*' + predicate + r'\s*\)\s*\{', source):
        start = source.index('{', match.start())
        args = arguments(source, start)
        if args:
            ranges.append((start, args[-1][1] + 1))
    for condition in predicates:
        for match in re.finditer(condition + r'\s*\?\s*', source):
            if (not _condition_start(source, match.start()) or
                    (condition != predicate and not known(
                        source[match.start():source.index('?', match.start())].strip(),
                        match.start()))):
                continue
            start = match.end()
            if start < len(source) and source[start] in "'\"":
                ranges.append((start, _string(source, start)[0]))
            elif start < len(source) and source[start] == '[':
                args = arguments(source, start)
                if args:
                    ranges.append((start, args[-1][1] + 1))

    # Maps are not exempt by name. They need a locale-selected read in source.
    for match in re.finditer(
            r'const\s+Map<String,\s*String>\s+(\w+)\s*=\s*'
            r'(?:<String,\s*String>)?\s*\{', source):
        name = match.group(1)
        reads = list(re.finditer(r'\b' + re.escape(name) + r'\b', source))
        guarded = set()
        for read in re.finditer(predicate + r'\s*\?\s*(' + re.escape(name) + r')\[', source):
            if _condition_start(source, read.start()):
                guarded.add(read.start(1))
        references = {read.start() for read in reads if read.start() != match.start(1)}
        if references and references <= guarded:
            args = arguments(source, source.index('{', match.start()))
            if args:
                ranges.append((source.index('{', match.start()), args[-1][1] + 1))

    # Fourteen-locale form: a map read only as the TURKISH argument of the
    # proven dispatcher, directly or through a `final` local whose every use
    # in its block is such an argument. Any other read keeps it checked.
    if localized_guard:
        tr_args = pair_ranges(source, 'localized', 2, named=LOCALIZED_NAMED)

        def in_tr(position):
            return any(a <= position < b for a, b in tr_args)

        finals = list(re.finditer(r'\bfinal\s+(\w+)\s*=\s*([^;]+);', source))
        for match in re.finditer(
                r'const\s+Map<String,\s*String>\s+(\w+)\s*=\s*'
                r'(?:<String,\s*String>)?\s*\{', source):
            name = match.group(1)
            refs = [m.start() for m in re.finditer(r'\b' + re.escape(name) + r'\b', source)
                    if m.start() != match.start(1)]
            proven = bool(refs)
            for ref in refs:
                if in_tr(ref):
                    continue
                binding = next((b for b in finals if b.start(2) <= ref < b.end(2)), None)
                if binding is None:
                    proven = False
                    break
                left, right = _block(source, binding.start())
                uses = [m.start() for m in re.finditer(
                    r'\b' + re.escape(binding[1]) + r'\b', source[left:right])
                    if left + m.start() != binding.start(1)]
                if not uses or not all(in_tr(left + u) for u in uses):
                    proven = False
                    break
            if proven:
                args = arguments(source, source.index('{', match.start()))
                if args:
                    ranges.append((source.index('{', match.start()), args[-1][1] + 1))

    # A guarded early return leaves only TR in the following switch. This is
    # limited to the enclosing function block; another function stays checked.
    for match in re.finditer(
            r"if\s*\(\s*Localizations\.localeOf\(context\)\.languageCode\s*"
            r"!=\s*'tr'\s*\)\s*\{\s*return [^;]+;\s*\}", source):
        opening = source.rfind('{', 0, match.start())
        spans = arguments(source, opening) if opening >= 0 else []
        if spans:
            ranges.append((match.end(), spans[-1][1]))
    return ranges


def literals_in_ranges(source, ranges):
    return {(source.count('\n', 0, start) + 1, text, start)
            for start, end, text in merged_dart_literals(source)
            if any(a <= start and end <= b for a, b in ranges)}


def code_only(source):
    """Source with every string literal body blanked (positions kept)."""
    chars = list(source)
    for start, end, _ in dart_literals(source):
        for i in range(start + 1, max(start + 1, end - 1)):
            if chars[i] != '\n':
                chars[i] = ' '
    return ''.join(chars)


def _only_at(source, needle, allowed):
    spans = [m.span() for pattern in allowed for m in re.finditer(pattern, source)]
    return all(any(a <= m.start() < b for a, b in spans)
               for m in re.finditer(needle, source))


def guarded_dart_contexts(sources):
    locale_source = sources.get('lib/app/app_locale.dart', '')
    direct = bool(re.search(LOCALE_DISPATCHER, locale_source))
    forwarded = (not direct and bool(re.search(TRANSLATION_DISPATCHER, locale_source)) and
                 translation_text_proof(
                     sources.get('lib/app/app_translation_catalog.dart', ''), sources))
    localized_guard = ((direct or forwarded) and
                       not _dispatcher_shadowed(locale_source, trusted_definition=True))
    study_source = sources.get('lib/app/study_review.dart', '')
    study_content = sources.get('lib/app/study_review_content.dart', '')
    study_guard = (localized_guard and not _dispatcher_shadowed(study_source) and
                   'const StudyText(this.en, this.tr)' in study_content and
                   bool(re.search(r'String inContext\(BuildContext context\)\s*=>\s*'
                                  r'_text\(context, en, tr\)\s*;', study_source)) and
                   bool(re.search(r'String _text\(BuildContext context, String en, String tr\)'
                                  r'\s*=>\s*localized\(context, en, tr\)\s*;', study_source)))
    guitar_source = sources.get('lib/app/guitar_journey.dart', '')
    guitar_guard = ('const GuitarText(this.en, this.tr)' in guitar_source and
                    bool(re.search(r"String of\(BuildContext context\)\s*=>\s*"
                                   r"Localizations\.localeOf\(context\)\.languageCode == 'tr' \? tr : en;",
                                   guitar_source)))
    # Fourteen-locale GuitarText forwards its pair (and only named `values`)
    # to the proven dispatcher. No code may read `.tr` of a text object
    # directly, which would bypass the dispatcher's tr-only branch.
    guitar_forwarded = (
        localized_guard and
        'const GuitarText(this.en, this.tr, {this.values = const {}});' in guitar_source and
        bool(re.search(r"String of\(BuildContext context\)\s*=>\s*"
                       r"localized\(context, en, tr, values: values\)\s*;", guitar_source)) and
        _only_at(guitar_source, r'\btr\b', [
            r'this\.tr\b', r'final String tr;', r"json\['tr'\]",
            r'localized\(context, en, tr, values: values\)']) and
        not any(re.search(r'(?<!this)\.tr\b', code_only(source)) for source in sources.values()))
    guitar_guard = guitar_guard or guitar_forwarded
    result = set()
    for file, source in sources.items():
        imports_locale = file == 'lib/app/app_locale.dart' or bool(re.search(
            r"import ['\"][^'\"]*app_locale.dart['\"]", source))
        reviewed_guard = (localized_guard and not _dispatcher_shadowed(source) and
                          'const _Reviewed(this.source, this.turkish);' in source and
                          bool(re.search(
                              r'String text\(BuildContext context, String id, String source\)\s*\{\s*'
                              r'final _Reviewed\? copy = _copies\[id\];\s*'
                              r'return copy != null && copy.source == source\s*'
                              r'\? localized\(context, source, copy.turkish\)\s*:\s*source;\s*\}', source)))
        ranges = dart_turkish_ranges(
            source, localized_guard=localized_guard and imports_locale,
            study_guard=study_guard and file == 'lib/app/study_review_content.dart',
            reviewed_guard=reviewed_guard,
            trusted_dispatcher_definition=file == 'lib/app/app_locale.dart')
        if guitar_guard and re.search(
                r"import ['\"][^'\"]*guitar_journey.dart['\"]", source):
            ranges += pair_ranges(source, 'GuitarText', 1,
                                  named=('values',) if guitar_forwarded else ())
        result.update((f'{file}:{line}', text, offset)
                      for line, text, offset in literals_in_ranges(source, ranges))
    return [(where, text) for where, text, _ in sorted(result)]


# ── Preference writers (rule E payload role) ────────────────────────────────
# A file that writes to disk is not a measurement writer merely because the
# write API matches. It is a PREFERENCE writer only when every write in it is
# `writeAsString(jsonEncode({...}), flush: true)` whose literal keys and value
# expressions are exactly one of these payloads. Anything else stays a new
# writer and re-opens every `stored: False` retention fact.
PREFERENCE_PAYLOADS = {
    'languageTag': 'locale',
    'mode': 'theme',
}
_WRITE_CALL = re.compile(
    r"writeAsString|writeAsBytes|SharedPreferences|Hive\.|sqflite|"
    r"\.insert\(|openDatabase")
_THEME_MEMBERS = {'system', 'light', 'dark'}


def _enclosing_method(source, position):
    """(parameter text, body) of the method whose block contains position."""
    for match in re.finditer(r'\b(\w+)\s*\(([^()]*)\)\s*(?:async\s*)?\{', source):
        opening = match.end() - 1
        spans = arguments(source, opening)
        if not spans and source[opening + 1:].lstrip().startswith('}'):
            continue
        end = spans[-1][1] + 1 if spans else opening + 1
        if opening < position < end:
            return match[2], source[opening:end]
    return None, None


def preference_payload_role(source):
    """'locale' / 'theme' when every disk write is a proven preference
    payload; otherwise None (fail-closed)."""
    writes = list(_WRITE_CALL.finditer(source))
    if not writes:
        return None
    roles = set()
    for write in writes:
        if write.group(0) != 'writeAsString':
            return None
        opening = write.end()
        if opening >= len(source) or source[opening] != '(':
            return None
        args = arguments(source, opening)
        if len(args) != 2 or source[slice(*args[1])].strip() != 'flush: true':
            return None
        payload = source[slice(*args[0])].strip()
        shape = re.fullmatch(
            r"jsonEncode\(\{\s*'schemaVersion':\s*1,\s*'(\w+)':\s*([\w.]+)\s*,?\s*\}\)",
            payload)
        if not shape or shape[1] not in PREFERENCE_PAYLOADS:
            return None
        key, value = shape[1], shape[2]
        parameters, body = _enclosing_method(source, write.start())
        if parameters is None:
            return None
        if key == 'languageTag':
            # A nullable String parameter, rejected unless it is a supported tag.
            if not re.fullmatch(r'\s*String\?\s+' + re.escape(value) + r'\s*', parameters):
                return None
            guard = (r"\{\s*if\s*\(\s*" + re.escape(value) + r"\s*!=\s*null\s*&&\s*"
                     r"!supportedLanguageTags\.contains\(" + re.escape(value) + r"\)\s*\)\s*\{\s*"
                     r"throw\b[^;]*;\s*\}")
            if not re.match(guard, body):
                return None
            if re.search(r'\b' + re.escape(value) + r'\s*(?:[-+*/|&^]|\?\?)?=(?!=)', body):
                return None
        else:
            # `<parameter>.name` of an enum whose members are only theme modes.
            member = re.fullmatch(r'(\w+)\.name', value)
            typed = member and re.fullmatch(r'\s*(\w+)\s+' + member[1] + r'\s*', parameters)
            if not typed:
                return None
            enum = re.search(r'\benum\s+' + re.escape(typed[1]) + r'\s*\{([^}]*)\}', source)
            if not enum or {m.strip() for m in enum[1].split(',') if m.strip()} - _THEME_MEMBERS:
                return None
        roles.add(PREFERENCE_PAYLOADS[key])
    return roles.pop() if len(roles) == 1 else None


# ── Generated message-ID map (rule F/H source role) ─────────────────────────
MESSAGE_ID_FILE = 'lib/app/app_message_ids.dart'
_ESCAPES = {'n': '\n', 't': '\t', 'r': '\r', 'b': '\b', 'f': '\f', 'v': '\v',
            '0': '\0'}


def dart_unescape(raw):
    """Value of a non-raw Dart literal body as read by the checker."""
    out, i = [], 0
    while i < len(raw):
        if raw[i] == '\\' and i + 1 < len(raw):
            nxt = raw[i + 1]
            if nxt == 'u' and raw.startswith('{', i + 2):
                end = raw.index('}', i + 3)
                out.append(chr(int(raw[i + 3:end], 16)))
                i = end + 1
                continue
            if nxt == 'u':
                out.append(chr(int(raw[i + 2:i + 6], 16)))
                i += 6
                continue
            out.append(_ESCAPES.get(nxt, nxt))
            i += 2
            continue
        out.append(raw[i])
        i += 1
    return ''.join(out)


def _literal(source, position):
    """(end, raw text) of one plain string literal at position, else None."""
    if position >= len(source) or source[position] not in "'\"":
        return None
    end, text, nested = _string(source, position)
    if nested or '${' in source[position:end]:
        return None
    return end, text


def _declaration(source, header):
    match = re.search(header, source)
    if not match:
        return None
    opening = match.end() - 1
    spans = arguments(source, opening)
    if not spans:
        return None
    closing = source.find('}', spans[-1][1])
    if not re.match(r'\s*;', source[closing + 1:]):
        return None
    return match.start(), closing + 1 + re.match(r'\s*;', source[closing + 1:]).end(), spans


def message_id_map(source):
    """Structure of the generated (english, turkish) -> id lookup map.

    Returns {'keys': [(line, en, tr)], 'plural': [(line, enOne, trOne)]}
    only when the comment-stripped file is exactly the three generated const
    maps with plain literal entries; any other code, interpolation or entry
    shape returns None and every literal stays an ordinary surface.
    """
    headers = [
        r'const appMessageIds = <\(String, String\), String>\{',
        r'const appMessagePlaceholders = <String, Map<String, int>>\{',
        r'const appMessagePluralSources = <String, Map<String, String>>\{',
    ]
    found = [_declaration(source, header) for header in headers]
    if any(item is None for item in found):
        return None
    remainder, cursor = '', 0
    for start, end, _ in sorted(found):
        remainder += source[cursor:start]
        cursor = end
    if (remainder + source[cursor:]).strip():
        return None
    line = lambda position: source.count('\n', 0, position) + 1
    keys, plural, by_id, plural_by_id = [], [], {}, {}
    for a, b in found[0][2]:
        entry = source[a:b]
        m = re.match(r'\s*\(\s*', entry)
        if not m:
            return None
        first = _literal(source, a + m.end())
        if not first:
            return None
        sep = re.match(r'\s*,\s*', source[first[0]:b])
        second = sep and _literal(source, first[0] + sep.end())
        if not second:
            return None
        close = re.match(r'\s*\)\s*:\s*', source[second[0]:b])
        ident = close and _literal(source, second[0] + close.end())
        if (not ident or source[ident[0]:b].strip() or
                not re.fullmatch(r'[0-9a-f]{16}', ident[1])):
            return None
        keys.append((line(a + m.end()), dart_unescape(first[1]), dart_unescape(second[1])))
        if ident[1] in by_id:
            return None
        by_id[ident[1]] = keys[-1][1:]
    for a, b in found[1][2]:
        if not re.fullmatch(r'\s*"[0-9a-f]{16}"\s*:\s*\{(?:\s*"\w+"\s*:\s*\d+\s*,?)*\s*\}\s*',
                            source[a:b]):
            return None
    for a, b in found[2][2]:
        m = re.match(r'\s*"([0-9a-f]{16})"\s*:\s*\{\s*"enOne"\s*:\s*', source[a:b])
        en = m and _literal(source, a + m.end())
        sep = en and re.match(r'\s*,\s*"trOne"\s*:\s*', source[en[0]:b])
        tr = sep and _literal(source, en[0] + sep.end())
        if not tr or not re.fullmatch(r'\s*\}\s*', source[tr[0]:b]):
            return None
        plural.append((line(a + m.end()), dart_unescape(en[1]), dart_unescape(tr[1])))
        plural_by_id[m[1]] = plural[-1][1:]
    if set(plural_by_id) - set(by_id):
        return None
    return {'keys': keys, 'plural': plural, 'by_id': by_id, 'plural_by_id': plural_by_id}


def catalog_parity(catalog, side, id_map):
    """Ids whose EN (side 0) or TR (side 1) catalog value is not the exact
    source text of its key; such a value would be an unchecked rendered
    surface. Returns (mismatched ids, missing ids, unknown ids)."""
    messages = catalog.get('messages') if isinstance(catalog, dict) else None
    if not isinstance(messages, dict):
        return None
    by_id, plural = id_map['by_id'], id_map['plural_by_id']
    mismatched = []
    for ident, value in messages.items():
        if ident not in by_id:
            continue
        source = by_id[ident][side]
        if isinstance(value, str):
            ok = value == source
        elif isinstance(value, dict):
            ok = (value.get('other') == source and
                  set(value) <= {'one', 'other'} and
                  value.get('one', plural.get(ident, (None, None))[side]) ==
                  plural.get(ident, (source, source))[side])
        else:
            ok = False
        if not ok:
            mismatched.append(ident)
    return (sorted(mismatched), sorted(set(by_id) - set(messages)),
            sorted(set(messages) - set(by_id)))


def forwarded_dispatcher_proven(sources):
    """The fourteen-locale dispatcher and its tr-only consumption are intact."""
    locale_source = sources.get('lib/app/app_locale.dart', '')
    return (bool(re.search(TRANSLATION_DISPATCHER, locale_source)) and
            not _dispatcher_shadowed(locale_source, trusted_definition=True) and
            translation_text_proof(
                sources.get('lib/app/app_translation_catalog.dart', ''), sources))
