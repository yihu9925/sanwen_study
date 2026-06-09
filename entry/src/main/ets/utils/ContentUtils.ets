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
