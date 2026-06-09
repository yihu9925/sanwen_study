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
  if (/^(def |class |import |from |return |if |for |while |function|var |let |const |async |await |try |catch |throw )/.test(trimmed)) {
    return true;
  }
  if (/[{}=;]$/.test(trimmed) && trimmed.length < 60) {
    return true;
  }
  return false;
}

export function parseContentSegments(text: string): ContentSegment[] {
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
      if (line.trim().length > 0) {
        segments.push({ type: 'text', content: line.trim() });
      }
    }
  }
  if (codeBuf.length > 0) {
    segments.push({ type: 'code', content: codeBuf.join('\n') });
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
