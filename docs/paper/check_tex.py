"""A static check of main.tex for when no LaTeX is installed.

It cannot replace compiling, but it catches the mistakes that most often break a
build: unbalanced braces, \\begin / \\end that do not pair, \\ref or \\eqref to a
label that does not exist, labels defined twice, \\cite keys with no \\bibitem (and
the reverse), unescaped ampersands, hashes and underscores in running text, and a
missing \\begin{document} or \\end{document}.

Usage:  python check_tex.py [main.tex]
Exit status 0 when nothing is wrong.
"""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else 'main.tex'
src = open(path, encoding='utf-8').read()
problems = []


def line_of(s, index):
    return s[:index].count('\n') + 1


# comments are not part of the document
text = re.sub(r'(?<!\\)%.*', '', src)

# braces: count only the ones that are not escaped (\{ and \})
depth = 0
for i, ch in enumerate(text):
    escaped = i > 0 and text[i - 1] == '\\'
    if escaped:
        continue
    if ch == '{':
        depth += 1
    elif ch == '}':
        depth -= 1
        if depth < 0:
            problems.append(f'unmatched }} near line {line_of(text, i)}')
            depth = 0
if depth != 0:
    problems.append(f'{depth} unclosed {{')

# environments pair up
stack = []
for m in re.finditer(r'\\(begin|end)\{([^}]+)\}', text):
    kind, name = m.groups()
    line = line_of(text, m.start())
    if kind == 'begin':
        stack.append((name, line))
    elif not stack or stack[-1][0] != name:
        top = stack[-1] if stack else 'nothing open'
        problems.append(f'\\end{{{name}}} at line {line} does not match {top}')
    else:
        stack.pop()
for name, line in stack:
    problems.append(f'\\begin{{{name}}} at line {line} is never closed')

# labels and references
labels = re.findall(r'\\label\{([^}]+)\}', text)
for l in sorted(set(labels)):
    if labels.count(l) > 1:
        problems.append(f'label {l} is defined {labels.count(l)} times')
for m in re.finditer(r'\\(?:ref|eqref|autoref|pageref)\{([^}]+)\}', text):
    if m.group(1) not in labels:
        problems.append(f'reference to a label that does not exist: {m.group(1)}')

# citations and the bibliography
items = set(re.findall(r'\\bibitem\{([^}]+)\}', text))
cited = set()
for m in re.finditer(r'\\cite[a-z]*\{([^}]+)\}', text):
    for key in (k.strip() for k in m.group(1).split(',')):
        cited.add(key)
        if key not in items:
            problems.append(f'citation {key} has no \\bibitem')
for k in sorted(items - cited):
    problems.append(f'\\bibitem {k} is never cited')

# special characters in running text, outside math, commands and tables
body = text.split('\\begin{document}')[-1].split('\\begin{thebibliography}')[0]
plain = re.sub(r'\\begin\{(?:tabular|tikzpicture|equation|align)\*?\}.*?'
               r'\\end\{(?:tabular|tikzpicture|equation|align)\*?\}', '', body,
               flags=re.S)
plain = re.sub(r'\\\[.*?\\\]', '', plain, flags=re.S)
plain = re.sub(r'\$[^$]*\$', '', plain)
plain = re.sub(r'\\texttt\{[^}]*\}', '', plain)
plain = re.sub(r'\\[a-zA-Z]+', '', plain)
for ch, name in (('&', 'ampersand'), ('#', 'hash'), ('_', 'underscore')):
    m = re.search(r'(?<!\\)' + re.escape(ch), plain)
    if m:
        start = plain.rfind('\n', 0, m.start()) + 1
        end = plain.find('\n', m.start())
        problems.append(f'unescaped {name} in text: ...{plain[start:end].strip()[:60]}')

for needed in ('\\begin{document}', '\\end{document}'):
    if needed not in text:
        problems.append(f'missing {needed}')

for p in problems:
    print('PROBLEM:', p)
print(f'{path}: {len(problems)} problem(s); {len(set(labels))} labels, '
      f'{len(items)} references in the bibliography')
sys.exit(1 if problems else 0)
