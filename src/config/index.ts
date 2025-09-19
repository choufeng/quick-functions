/**
 * 配置系统入口文件
 * Configuration system entry point
 */

// 导出主要的类
export { ConfigManager } from './manager';
export { ConfigParser } from './parser';
export { ConfigValidator } from './validator';

// 导出类型
export type {
  Config,
  ChainConfig,
  LegacyConfig,
  ChainNode,
  PackageNode,
  AppNode,
  ConfigFile,
  ValidationResult,
  ValidationError,
  ParsedChainConfig,
  ParsedChainNode
} from '../types/config';

export type {
  ParsedConfig,
  ParsedLegacyConfig,
  ParseConfigResult,
  ParsedConfigResult
} from './parser';

export type {
  LoadConfigResult,
  GetConfigResult,
  ListConfigsResult,
  ConfigSummary
} from './manager';

// 便捷的工厂函数
export const createConfigManager = (configPath?: string) => {
  return ConfigManager.create(configPath);
};

// 默认配置管理器实例
export const defaultConfigManager = ConfigManager.create();