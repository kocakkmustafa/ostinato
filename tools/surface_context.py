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


def pair_ranges(source, name, turkish_index, arity=None):
    ranges = []
    for match in re.finditer(r'\b' + re.escape(name) + r'\s*\(', source):
        # A method with the same spelling is not the imported dispatcher.
        if source[:match.start()].rstrip().endswith('.'):
            continue
        args = arguments(source, source.index('(', match.start()))
        if len(args) == (arity or turkish_index + 1):
            ranges.append(args[turkish_index])
    return ranges


LOCALE_DISPATCHER = (
    r"String localized\(BuildContext context, String english, String turkish\)\s*=>\s*"
    r"Localizations\.localeOf\(context\)\.languageCode == 'tr' \? turkish : english;")


def _dispatcher_shadowed(source, trusted_definition=False):
    # The imported name may resolve to a local/member callable instead. Such
    # a file retains language checks rather than guessing Dart name resolution.
    if trusted_definition:
        source = re.sub(LOCALE_DISPATCHER, '', source, count=1)
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
        ranges += pair_ranges(source, 'localized', 2)
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


def guarded_dart_contexts(sources):
    locale_source = sources.get('lib/app/app_locale.dart', '')
    localized_guard = (bool(re.search(LOCALE_DISPATCHER, locale_source)) and
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
            ranges += pair_ranges(source, 'GuitarText', 1)
        result.update((f'{file}:{line}', text, offset)
                      for line, text, offset in literals_in_ranges(source, ranges))
    return [(where, text) for where, text, _ in sorted(result)]
