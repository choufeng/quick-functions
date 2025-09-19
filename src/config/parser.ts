/**
 * 配置解析器
 * Configuration parser
 */

import path from 'path';
import os from 'os';
import {
  Config,
  ChainConfig,
  LegacyConfig,
  ParsedChainConfig,
  ParsedChainNode,
  ConfigFile,
  ChainNode,
  ValidationResult
} from '../types/config';
import { ConfigValidator } from './validator';

export class ConfigParser {
  /**
   * 解析并验证配置文件
   * Parse and validate configuration file
   */
  public static parseConfigFile(configData: any): ParsedConfigResult {
    // 首先验证配置
    const validation = ConfigValidator.validateConfigFile(configData);
    if (!validation.valid) {
      return {
        success: false,
        errors: validation.errors,
        configs: []
      };
    }

    const configFile = configData as ConfigFile;
    const parsedConfigs: ParsedConfig[] = [];
    const allErrors: ValidationError[] = [];

    // 解析每个配置
    configFile.configs.forEach((config, index) => {
      const parseResult = this.parseConfig(config);
      if (parseResult.success) {
        parsedConfigs.push(parseResult.config!);
      } else {
        parseResult.errors.forEach(error => {
          allErrors.push({
            ...error,
            path: `configs[${index}].${error.path}`
          });
        });
      }
    });

    return {
      success: allErrors.length === 0,
      errors: allErrors,
      configs: parsedConfigs
    };
  }

  /**
   * 解析单个配置
   * Parse single configuration
   */
  public static parseConfig(config: Config): ParseConfigResult {
    const configType = config.type || 'legacy';

    if (configType === 'chain') {
      return this.parseChainConfig(config as ChainConfig);
    } else if (configType === 'legacy') {
      return this.parseLegacyConfig(config as LegacyConfig);
    } else {
      return {
        success: false,
        errors: [{
          path: 'type',
          message: `不支持的配置类型: ${configType} | Unsupported config type: ${configType}`,
          code: 'UNSUPPORTED_TYPE'
        }]
      };
    }
  }

  /**
   * 解析链式配置
   * Parse chain configuration
   */
  private static parseChainConfig(config: ChainConfig): ParseConfigResult {
    try {
      const parsedNodes: ParsedChainNode[] = [];

      // 解析每个链节点
      for (let i = 0; i < config.chain.length; i++) {
        const node = config.chain[i];
        const parsedNode = this.parseChainNode(node);
        parsedNodes.push(parsedNode);
      }

      const parsedConfig: ParsedChainConfig = {
        type: 'chain',
        node_count: parsedNodes.length,
        nodes: parsedNodes
      };

      return {
        success: true,
        config: {
          name: config.name,
          description: config.description,
          type: 'chain',
          parsedData: parsedConfig
        }
      };
    } catch (error) {
      return {
        success: false,
        errors: [{
          path: 'chain',
          message: `链式配置解析失败: ${error.message} | Chain config parsing failed: ${error.message}`,
          code: 'PARSE_ERROR'
        }]
      };
    }
  }

  /**
   * 解析链节点
   * Parse chain node
   */
  private static parseChainNode(node: ChainNode): ParsedChainNode {
    const baseNode: ParsedChainNode = {
      type: node.type,
      name: node.name,
      dependencies: node.dependencies || []
    };

    if (node.type === 'package') {
      return {
        ...baseNode,
        package_dir: this.expandPath(node.package_dir),
        package_name: node.package_name,
        build_command: node.build_command || './pnpm run build'
      };
    } else if (node.type === 'app') {
      return {
        ...baseNode,
        app_dir: this.expandPath(node.app_dir),
        start_command: node.start_command || './pnpm start'
      };
    }

    throw new Error(`Unknown node type: ${node.type}`);
  }

  /**
   * 解析传统配置
   * Parse legacy configuration
   */
  private static parseLegacyConfig(config: LegacyConfig): ParseConfigResult {
    try {
      const parsedConfig: ParsedLegacyConfig = {
        name: config.name,
        description: config.description,
        type: 'legacy',
        package_dir: this.expandPath(config.package_dir),
        app_dir: this.expandPath(config.app_dir),
        package_name: config.package_name,
        start_command: config.start_command || './pnpm start',
        build_command: config.build_command || './pnpm run build'
      };

      return {
        success: true,
        config: {
          name: config.name,
          description: config.description,
          type: 'legacy',
          parsedData: parsedConfig
        }
      };
    } catch (error) {
      return {
        success: false,
        errors: [{
          path: 'root',
          message: `传统配置解析失败: ${error.message} | Legacy config parsing failed: ${error.message}`,
          code: 'PARSE_ERROR'
        }]
      };
    }
  }

  /**
   * 展开路径中的环境变量
   * Expand environment variables in paths
   */
  private static expandPath(inputPath: string): string {
    if (!inputPath) return inputPath;

    // 替换 $HOME
    let expandedPath = inputPath.replace(/\$HOME/g, os.homedir());
    
    // 替换 ~ 
    expandedPath = expandedPath.replace(/^~(?=\/|$)/, os.homedir());

    // 替换其他环境变量 $VAR_NAME
    expandedPath = expandedPath.replace(/\$([A-Z_][A-Z0-9_]*)/g, (match, varName) => {
      return process.env[varName] || match;
    });

    return path.normalize(expandedPath);
  }

  /**
   * 根据名称查找配置
   * Find configuration by name
   */
  public static findConfigByName(configs: ParsedConfig[], name?: string): ParsedConfig | null {
    if (!name) {
      return configs.length > 0 ? configs[0] : null;
    }

    return configs.find(config => config.name === name) || null;
  }

  /**
   * 获取链式配置的主要节点（用于向后兼容）
   * Get primary node from chain config (for backward compatibility)
   */
  public static getPrimaryNodeFromChain(chainConfig: ParsedChainConfig): ParsedChainNode | null {
    if (chainConfig.nodes.length === 0) {
      return null;
    }

    // 优先选择第一个包节点
    const packageNode = chainConfig.nodes.find(node => node.type === 'package');
    if (packageNode) {
      return packageNode;
    }

    // 如果没有包节点，返回第一个应用节点
    return chainConfig.nodes.find(node => node.type === 'app') || chainConfig.nodes[0];
  }
}

// 导出的类型
export interface ParsedConfig {
  name: string;
  description: string;
  type: 'chain' | 'legacy';
  parsedData: ParsedChainConfig | ParsedLegacyConfig;
}

export interface ParsedLegacyConfig {
  name: string;
  description: string;
  type: 'legacy';
  package_dir: string;
  app_dir: string;
  package_name: string;
  start_command: string;
  build_command: string;
}

export interface ValidationError {
  path: string;
  message: string;
  code: string;
}

export interface ParseConfigResult {
  success: boolean;
  errors?: ValidationError[];
  config?: ParsedConfig;
}

export interface ParsedConfigResult {
  success: boolean;
  errors: ValidationError[];
  configs: ParsedConfig[];
}