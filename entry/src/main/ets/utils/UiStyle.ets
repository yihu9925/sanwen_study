export interface StyleColors {
  pageBg: string;
  cardBg: string;
  accent: string;
  accentLight: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  divider: string;
  cardRadius: number;
  cardShadow: string;
}

const defaultLight: StyleColors = {
  pageBg: '#F5F5F5',
  cardBg: '#FFFFFF',
  accent: '#007DFF',
  accentLight: '#E6F2FF',
  textPrimary: '#000000',
  textSecondary: '#666666',
  textTertiary: '#999999',
  divider: '#E5E5E5',
  cardRadius: 12,
  cardShadow: ''
};

const defaultDark: StyleColors = {
  pageBg: '#222222',
  cardBg: '#333333',
  accent: '#007DFF',
  accentLight: '#1A3A5C',
  textPrimary: '#FFFFFF',
  textSecondary: '#AAAAAA',
  textTertiary: '#999999',
  divider: '#444444',
  cardRadius: 12,
  cardShadow: ''
};

const warmLight: StyleColors = {
  pageBg: '#F5F0EB',
  cardBg: '#FFFDF5',
  accent: '#D4894A',
  accentLight: '#FFF0E0',
  textPrimary: '#3D3228',
  textSecondary: '#7A6B5A',
  textTertiary: '#A89888',
  divider: '#E8E0D5',
  cardRadius: 16,
  cardShadow: '0px 2px 8px rgba(180, 150, 120, 0.15)'
};

const warmDark: StyleColors = {
  pageBg: '#2C2418',
  cardBg: '#3D3224',
  accent: '#E8A85A',
  accentLight: '#4A3D2E',
  textPrimary: '#F0E8D8',
  textSecondary: '#C4B5A0',
  textTertiary: '#A09080',
  divider: '#4A3D30',
  cardRadius: 16,
  cardShadow: ''
};

const midnightLight: StyleColors = {
  pageBg: '#F0F2F5',
  cardBg: '#FFFFFF',
  accent: '#D4A843',
  accentLight: '#FDF6E3',
  textPrimary: '#1A202C',
  textSecondary: '#4A5568',
  textTertiary: '#A0AEC0',
  divider: '#E2E8F0',
  cardRadius: 12,
  cardShadow: ''
};

const midnightDark: StyleColors = {
  pageBg: '#0F141E',
  cardBg: '#1A2332',
  accent: '#E8C24A',
  accentLight: '#2A3140',
  textPrimary: '#E2E8F0',
  textSecondary: '#94A3B8',
  textTertiary: '#64748B',
  divider: '#2D3748',
  cardRadius: 12,
  cardShadow: ''
};

const forestLight: StyleColors = {
  pageBg: '#F0F7F0',
  cardBg: '#FFFFFF',
  accent: '#2E7D4E',
  accentLight: '#E8F5E9',
  textPrimary: '#1B3A2A',
  textSecondary: '#5A7A6A',
  textTertiary: '#9AB0A0',
  divider: '#DCE8E0',
  cardRadius: 14,
  cardShadow: ''
};

const forestDark: StyleColors = {
  pageBg: '#1A2E22',
  cardBg: '#243D30',
  accent: '#4CAF50',
  accentLight: '#1E3A28',
  textPrimary: '#E8F0EA',
  textSecondary: '#A0C0B0',
  textTertiary: '#7A9A8A',
  divider: '#2A4D38',
  cardRadius: 14,
  cardShadow: ''
};

const sakuraLight: StyleColors = {
  pageBg: '#FFF5F7',
  cardBg: '#FFFFFF',
  accent: '#D4617A',
  accentLight: '#FFE8EE',
  textPrimary: '#3D2C34',
  textSecondary: '#8A6E7A',
  textTertiary: '#B89EAA',
  divider: '#F0E0E6',
  cardRadius: 16,
  cardShadow: '0px 2px 8px rgba(180, 140, 150, 0.12)'
};

const sakuraDark: StyleColors = {
  pageBg: '#2E2026',
  cardBg: '#3F2E36',
  accent: '#F28BA8',
  accentLight: '#4A303C',
  textPrimary: '#F5E8EE',
  textSecondary: '#C8A8B8',
  textTertiary: '#9A7A8A',
  divider: '#4A3840',
  cardRadius: 16,
  cardShadow: ''
};

const inkLight: StyleColors = {
  pageBg: '#F5F0E8',
  cardBg: '#FCF8F0',
  accent: '#C43838',
  accentLight: '#FDF0E8',
  textPrimary: '#2C2418',
  textSecondary: '#6A5E4E',
  textTertiary: '#9A8E7E',
  divider: '#E0D8C8',
  cardRadius: 12,
  cardShadow: ''
};

const inkDark: StyleColors = {
  pageBg: '#1E1A14',
  cardBg: '#2E2820',
  accent: '#D4604A',
  accentLight: '#3A3028',
  textPrimary: '#E0D8C8',
  textSecondary: '#A89E8E',
  textTertiary: '#7A7060',
  divider: '#3E3830',
  cardRadius: 12,
  cardShadow: ''
};

export class UiStyle {
  static getColors(style: string, dark: boolean): StyleColors {
    const palettes: Record<string, StyleColors[]> = {
      'default': [defaultLight, defaultDark],
      'warm': [warmLight, warmDark],
      'midnight': [midnightLight, midnightDark],
      'forest': [forestLight, forestDark],
      'sakura': [sakuraLight, sakuraDark],
      'ink': [inkLight, inkDark]
    };
    const pair = palettes[style] || palettes['default'];
    return dark ? pair[1] : pair[0];
  }

  static getStyleLabel(style: string): string {
    const labels: Record<string, string> = {
      'default': '默认',
      'warm': '暖阳',
      'midnight': '极夜',
      'forest': '森林',
      'sakura': '樱花',
      'ink': '墨水'
    };
    return labels[style] || style;
  }
}
