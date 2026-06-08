// API配置管理服务
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export interface LLMConfig {
  apiKey: string;
  apiBase: string;
  model: string;
}

export class ConfigService {
  private static prefs: preferences.Preferences | null = null;
  private static readonly STORE_NAME = 'app_config';
  private static readonly KEY_API_KEY = 'llm_api_key';
  private static readonly KEY_API_BASE = 'llm_api_base';
  private static readonly KEY_MODEL = 'llm_model';
  private static readonly DEFAULT_BASE = 'https://api.openai.com/v1';
  private static readonly DEFAULT_MODEL = 'gpt-4';

  static async init(context: common.UIAbilityContext): Promise<void> {
    ConfigService.prefs = await preferences.getPreferences(context, ConfigService.STORE_NAME);
  }

  static async getLLMConfig(): Promise<LLMConfig> {
    if (!ConfigService.prefs) {
      return {
        apiKey: '',
        apiBase: ConfigService.DEFAULT_BASE,
        model: ConfigService.DEFAULT_MODEL,
      };
    }
    const apiKey: string = (await ConfigService.prefs.get(ConfigService.KEY_API_KEY, '')) as string;
    const apiBase: string = (await ConfigService.prefs.get(ConfigService.KEY_API_BASE, ConfigService.DEFAULT_BASE)) as string;
    const model: string = (await ConfigService.prefs.get(ConfigService.KEY_MODEL, ConfigService.DEFAULT_MODEL)) as string;
    return { apiKey, apiBase, model };
  }

  static async saveApiKey(key: string): Promise<void> {
    if (ConfigService.prefs) {
      await ConfigService.prefs.put(ConfigService.KEY_API_KEY, key);
      await ConfigService.prefs.flush();
    }
  }

  static async saveApiBase(base: string): Promise<void> {
    if (ConfigService.prefs) {
      await ConfigService.prefs.put(ConfigService.KEY_API_BASE, base);
      await ConfigService.prefs.flush();
    }
  }

  static async saveModel(model: string): Promise<void> {
    if (ConfigService.prefs) {
      await ConfigService.prefs.put(ConfigService.KEY_MODEL, model);
      await ConfigService.prefs.flush();
    }
  }
}
