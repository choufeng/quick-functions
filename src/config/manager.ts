/**
 * 配置管理器
 * Configuration manager
 */

import fs from 'fs';
import path from 'path';
import os from 'os';
import {
  ConfigFile,
  Config,
  ValidationResult
} from '../types/config';
import { ConfigParser, ParsedConfig, ParsedConfigResult } from './parser';
import { ConfigValidator } from './validator';

export class ConfigManager {
  private static readonly DEFAULT_CONFIG_PATH = path.join(os.homedir(), '.quick-functions', 'devup-configs.json');
  private configPath: string;
  private cachedConfigs: ParsedConfig[] | null = null;
  private lastModified: number | null = null;

  constructor(configPath?: string) {
    this.configPath = configPath || ConfigManager.DEFAULT_CONFIG_PATH;
  }

  /**
   * 加载配置文件
   * Load configuration file
   */
  public async loadConfigs(force: boolean = false): Promise<LoadConfigResult> {
    try {
      // 检查缓存
      if (!force && this.cachedConfigs && this.isConfigCacheValid()) {
        return {
          success: true,
          configs: this.cachedConfigs
        };
      }

      // 检查文件是否存在
      if (!fs.existsSync(this.configPath)) {
        return this.createDefaultConfig();
      }

      // 读取文件
      const fileContent = fs.readFileSync(this.configPath, 'utf-8');
      let configData: any;

      try {
        configData = JSON.parse(fileContent);
      } catch (parseError) {
        return {
          success: false,
          errors: [{
            path: 'file',
            message: `JSON解析失败: ${parseError.message} | JSON parsing failed: ${parseError.message}`,
            code: 'JSON_PARSE_ERROR'
          }]
        };
      }

      // 解析配置
      const parseResult = ConfigParser.parseConfigFile(configData);
      if (!parseResult.success) {
        return {
          success: false,
          errors: parseResult.errors
        };
      }

      // 缓存结果
      this.cachedConfigs = parseResult.configs;
      const stats = fs.statSync(this.configPath);
      this.lastModified = stats.mtime.getTime();

      return {
        success: true,
        configs: parseResult.configs
      };

    } catch (error) {
      return {
        success: false,
        errors: [{
          path: 'file',
          message: `读取配置文件失败: ${error.message} | Failed to read config file: ${error.message}`,
          code: 'FILE_READ_ERROR'
        }]
      };
    }
  }

  /**
   * 根据名称获取配置
   * Get configuration by name
   */
  public async getConfig(name?: string): Promise<GetConfigResult> {
    const loadResult = await this.loadConfigs();
    if (!loadResult.success) {
      return {
        success: false,
        errors: loadResult.errors!
      };
    }

    const config = ConfigParser.findConfigByName(loadResult.configs!, name);
    if (!config) {
      if (name) {
        return {
          success: false,
          errors: [{
            path: 'name',
            message: `找不到配置: ${name} | Config not found: ${name}`,
            code: 'CONFIG_NOT_FOUND'
          }]
        };
      } else {
        return {
          success: false,
          errors: [{
            path: 'configs',
            message: '没有可用的配置 | No available configurations',
            code: 'NO_CONFIGS'
          }]
        };
      }
    }

    return {
      success: true,
      config
    };
  }

  /**
   * 列出所有配置
   * List all configurations
   */
  public async listConfigs(): Promise<ListConfigsResult> {
    const loadResult = await this.loadConfigs();
    if (!loadResult.success) {
      return {
        success: false,
        errors: loadResult.errors!
      };
    }

    const configSummaries = loadResult.configs!.map((config, index) => ({
      name: config.name,
      description: config.description,
      type: config.type,
      isDefault: index === 0
    }));

    return {
      success: true,
      configs: configSummaries
    };
  }

  /**
   * 验证配置文件
   * Validate configuration file
   */
  public async validateConfig(): Promise<ValidationResult> {
    try {
      if (!fs.existsSync(this.configPath)) {
        return {
          valid: false,
          errors: [{
            path: 'file',
            message: `配置文件不存在: ${this.configPath} | Config file not found: ${this.configPath}`,
            code: 'FILE_NOT_FOUND'
          }]
        };
      }

      const fileContent = fs.readFileSync(this.configPath, 'utf-8');
      let configData: any;

      try {
        configData = JSON.parse(fileContent);
      } catch (parseError) {
        return {
          valid: false,
          errors: [{
            path: 'file',
            message: `JSON解析失败: ${parseError.message} | JSON parsing failed: ${parseError.message}`,
            code: 'JSON_PARSE_ERROR'
          }]
        };
      }

      return ConfigValidator.validateConfigFile(configData);

    } catch (error) {
      return {
        valid: false,
        errors: [{
          path: 'file',
          message: `验证失败: ${error.message} | Validation failed: ${error.message}`,
          code: 'VALIDATION_ERROR'
        }]
      };
    }
  }

  /**
   * 获取配置文件路径
   * Get configuration file path
   */
  public getConfigPath(): string {
    return this.configPath;
  }

  /**
   * 清除缓存
   * Clear cache
   */
  public clearCache(): void {
    this.cachedConfigs = null;
    this.lastModified = null;
  }

  /**
   * 检查配置缓存是否有效
   * Check if config cache is valid
   */
  private isConfigCacheValid(): boolean {
    if (!this.lastModified || !fs.existsSync(this.configPath)) {
      return false;
    }

    const stats = fs.statSync(this.configPath);
    return stats.mtime.getTime() === this.lastModified;
  }

  /**
   * 创建默认配置
   * Create default configuration
   */
  private createDefaultConfig(): LoadConfigResult {
    const defaultConfig: ParsedConfig = {
      name: 'default',
      description: 'Default devup configuration',
      type: 'legacy',
      parsedData: {
        name: 'default',
        description: 'Default devup configuration',
        type: 'legacy',
        package_dir: path.join(os.homedir(), 'development', 'uc-frontend', 'packages', 'modal--agent-orders.react'),
        app_dir: path.join(os.homedir(), 'development', 'uc-frontend', 'apps', 'lab'),
        package_name: '@uc/modal--agent-orders.react',
        start_command: './pnpm start',
        build_command: './pnpm run build'
      }
    };

    console.warn(`⚠️  配置文件不存在，使用默认配置 | Config file not found, using default config`);
    
    return {
      success: true,
      configs: [defaultConfig]
    };
  }

  /**
   * 静态方法：创建配置管理器实例
   * Static method: create config manager instance
   */
  public static create(configPath?: string): ConfigManager {
    return new ConfigManager(configPath);
  }

  /**
   * 静态方法：获取默认配置路径
   * Static method: get default config path
   */
  public static getDefaultConfigPath(): string {
    return ConfigManager.DEFAULT_CONFIG_PATH;
  }
}

// 导出的类型
export interface LoadConfigResult {
  success: boolean;
  configs?: ParsedConfig[];
  errors?: ValidationError[];
}

export interface GetConfigResult {
  success: boolean;
  config?: ParsedConfig;
  errors?: ValidationError[];
}

export interface ListConfigsResult {
  success: boolean;
  configs?: ConfigSummary[];
  errors?: ValidationError[];
}

export interface ConfigSummary {
  name: string;
  description: string;
  type: 'chain' | 'legacy';
  isDefault: boolean;
}

export interface ValidationError {
  path: string;
  message: string;
  code: string;
}