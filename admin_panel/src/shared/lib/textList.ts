export function stringifyTextList(items: string[]): string {
  return items.join('\n');
}

export function parseTextList(rawValue: string): string[] {
  return rawValue
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean);
}
