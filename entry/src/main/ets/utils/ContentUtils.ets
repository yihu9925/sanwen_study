export interface ContentSegment {
  type: 'text' | 'code';
  content: string;
}

function isCodeLine(line: string): boolean {
  const trimmed: string = line.trim();
  if (!trimmed) {
    return false;
  }
  if (line.startsWith('  ') || line.startsWith('\t')) {
    return true;
  }
  if (/^(def |class |import |from |return |if |for |while |function|var |let |const |async |await |try |catch |throw |print |console|int |float |str |list |dict |set |import |export |type |interface|enum |struct |public |private |protected|static |void )/.test(trimmed)) {
    return true;
  }
  if (/[\[\]{}();=]/.test(trimmed) && trimmed.length < 60) {
    return true;
  }
  if (/^[a-z_][a-z0-9_]*\(/.test(trimmed)) {
    return true;
  }
  return false;
}

function parseTextSegments(text: string): ContentSegment[] {
  const lines: string[] = text.split('\n');
  const segments: ContentSegment[] = [];
  let codeBuf: string[] = [];

  for (const line of lines) {
    if (isCodeLine(line)) {
      codeBuf.push(line);
    } else {
      if (codeBuf.length > 0) {
        segments.push({ type: 'code', content: codeBuf.join('\n') });
        codeBuf = [];
      }
      const trimmed: string = line.trim();
      if (trimmed.length > 0) {
        segments.push({ type: 'text', content: trimmed });
      }
    }
  }
  if (codeBuf.length > 0) {
    segments.push({ type: 'code', content: codeBuf.join('\n') });
  }
  return segments;
}

export function parseContentSegments(text: string): ContentSegment[] {
  const segments: ContentSegment[] = [];
  const markerStart: string = '[CODE]';
  const markerEnd: string = '[/CODE]';

  let remaining: string = text;
  let idxStart: number = remaining.indexOf(markerStart);
  let idxEnd: number = remaining.indexOf(markerEnd);

  if (idxStart < 0 || idxEnd < 0) {
    return parseTextSegments(text);
  }

  while (idxStart >= 0 && idxEnd >= 0) {
    if (idxStart > 0) {
      const beforeCode: string = remaining.substring(0, idxStart);
      if (beforeCode.trim().length > 0) {
        const textSegs: ContentSegment[] = parseTextSegments(beforeCode);
        for (const seg of textSegs) {
          segments.push(seg);
        }
      }
    }
    const codeContent: string = remaining.substring(idxStart + markerStart.length, idxEnd);
    if (codeContent.trim().length > 0) {
      segments.push({ type: 'code', content: codeContent });
    }
    remaining = remaining.substring(idxEnd + markerEnd.length);
    idxStart = remaining.indexOf(markerStart);
    idxEnd = remaining.indexOf(markerEnd);
  }

  if (remaining.trim().length > 0) {
    const textSegs: ContentSegment[] = parseTextSegments(remaining);
    for (const seg of textSegs) {
      segments.push(seg);
    }
  }

  return segments;
}

export function parseParagraphs(text: string): string[] {
  const byNewline: string[] = text.split('\n').filter((p: string): boolean => p.trim().length > 0);
  if (byNewline.length > 1) {
    return byNewline;
  }
  const sentences: string[] = [];
  let buf: string = '';
  for (let i: number = 0; i < text.length; i++) {
    buf += text[i];
    if ('\u3002\uFF01\uFF1F.!?'.indexOf(text[i]) >= 0) {
      sentences.push(buf.trim());
      buf = '';
    }
  }
  if (buf.trim().length > 0) {
    sentences.push(buf.trim());
  }
  if (sentences.length <= 1) {
    return [text];
  }
  const groups: string[] = [];
  for (let i: number = 0; i < sentences.length; i += 3) {
    const end: number = Math.min(i + 3, sentences.length);
    groups.push(sentences.slice(i, end).join(''));
  }
  return groups;
}
