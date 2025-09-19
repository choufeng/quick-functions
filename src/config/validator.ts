/**
 * 配置验证器
 * Configuration validator
 */

import {
  Config,
  ChainConfig,
  LegacyConfig,
  ValidationResult,
  ValidationError,
  ConfigFile,
  ChainNode,
  PackageNode,
  AppNode
} from '../types/config';

export class ConfigValidator {
  /**
   * 验证完整的配置文件
   * Validate complete configuration file
   */
  public static validateConfigFile(configFile: any): ValidationResult {
    const errors: ValidationError[] = [];

    // 检查configs数组
    if (!configFile || typeof configFile !== 'object') {
      errors.push({
        path: 'root',
        message: '配置文件必须是对象 | Configuration file must be an object',
        code: 'INVALID_ROOT_TYPE'
      });
      return { valid: false, errors };
    }

    if (!Array.isArray(configFile.configs)) {
      errors.push({
        path: 'configs',
        message: 'configs必须是数组 | configs must be an array',
        code: 'INVALID_CONFIGS_TYPE'
      });
      return { valid: false, errors };
    }

    if (configFile.configs.length === 0) {
      errors.push({
        path: 'configs',
        message: 'configs数组不能为空 | configs array cannot be empty',
        code: 'EMPTY_CONFIGS'
      });
      return { valid: false, errors };
    }

    // 验证每个配置
    configFile.configs.forEach((config: any, index: number) => {
      const configErrors = this.validateConfig(config);
      configErrors.errors.forEach(error => {
        errors.push({
          ...error,
          path: `configs[${index}].${error.path}`
        });
      });
    });

    // 检查配置名称的唯一性
    const names = configFile.configs.map((c: any) => c.name).filter((n: any) => n);
    const duplicateNames = names.filter((name: string, index: number) => 
      names.indexOf(name) !== index
    );
    
    if (duplicateNames.length > 0) {
      errors.push({
        path: 'configs',
        message: `配置名称重复: ${duplicateNames.join(', ')} | Duplicate config names: ${duplicateNames.join(', ')}`,
        code: 'DUPLICATE_NAMES'
      });
    }

    return { valid: errors.length === 0, errors };
  }

  /**
   * 验证单个配置
   * Validate single configuration
   */
  public static validateConfig(config: any): ValidationResult {
    const errors: ValidationError[] = [];

    if (!config || typeof config !== 'object') {
      errors.push({
        path: 'root',
        message: '配置必须是对象 | Config must be an object',
        code: 'INVALID_CONFIG_TYPE'
      });
      return { valid: false, errors };
    }

    // 检查必需字段
    if (!config.name || typeof config.name !== 'string') {
      errors.push({
        path: 'name',
        message: 'name字段必须是非空字符串 | name field must be a non-empty string',
        code: 'MISSING_NAME'
      });
    }

    if (!config.description || typeof config.description !== 'string') {
      errors.push({
        path: 'description',
        message: 'description字段必须是非空字符串 | description field must be a non-empty string',
        code: 'MISSING_DESCRIPTION'
      });
    }

    // 根据类型验证
    const configType = config.type || 'legacy';
    
    if (configType === 'chain') {
      const chainErrors = this.validateChainConfig(config as ChainConfig);
      errors.push(...chainErrors.errors);
    } else if (configType === 'legacy') {
      const legacyErrors = this.validateLegacyConfig(config as LegacyConfig);
      errors.push(...legacyErrors.errors);
    } else {
      errors.push({
        path: 'type',
        message: `未知的配置类型: ${configType} | Unknown config type: ${configType}`,
        code: 'INVALID_TYPE'
      });
    }

    return { valid: errors.length === 0, errors };
  }

  /**
   * 验证链式配置
   * Validate chain configuration
   */
  private static validateChainConfig(config: ChainConfig): ValidationResult {
    const errors: ValidationError[] = [];

    if (!Array.isArray(config.chain)) {
      errors.push({
        path: 'chain',
        message: 'chain字段必须是数组 | chain field must be an array',
        code: 'INVALID_CHAIN_TYPE'
      });
      return { valid: false, errors };
    }

    if (config.chain.length === 0) {
      errors.push({
        path: 'chain',
        message: 'chain数组不能为空 | chain array cannot be empty',
        code: 'EMPTY_CHAIN'
      });
      return { valid: false, errors };
    }

    // 验证每个链节点
    const nodeNames: string[] = [];
    config.chain.forEach((node, index) => {
      const nodeErrors = this.validateChainNode(node);
      nodeErrors.errors.forEach(error => {
        errors.push({
          ...error,
          path: `chain[${index}].${error.path}`
        });
      });

      // 收集节点名称
      if (node.name) {
        nodeNames.push(node.name);
      }
    });

    // 检查节点名称唯一性
    const duplicateNodeNames = nodeNames.filter((name, index) => 
      nodeNames.indexOf(name) !== index
    );
    
    if (duplicateNodeNames.length > 0) {
      errors.push({
        path: 'chain',
        message: `链节点名称重复: ${duplicateNodeNames.join(', ')} | Duplicate node names: ${duplicateNodeNames.join(', ')}`,
        code: 'DUPLICATE_NODE_NAMES'
      });
    }

    // 验证依赖关系
    const depErrors = this.validateDependencies(config.chain, nodeNames);
    errors.push(...depErrors.errors);

    return { valid: errors.length === 0, errors };
  }

  /**
   * 验证单个链节点
   * Validate single chain node
   */
  private static validateChainNode(node: any): ValidationResult {
    const errors: ValidationError[] = [];

    if (!node || typeof node !== 'object') {
      errors.push({
        path: 'root',
        message: '链节点必须是对象 | Chain node must be an object',
        code: 'INVALID_NODE_TYPE'
      });
      return { valid: false, errors };
    }

    // 验证类型
    if (!node.type || !['package', 'app'].includes(node.type)) {
      errors.push({
        path: 'type',
        message: 'type必须是"package"或"app" | type must be "package" or "app"',
        code: 'INVALID_NODE_TYPE_VALUE'
      });
    }

    // 验证名称
    if (!node.name || typeof node.name !== 'string') {
      errors.push({
        path: 'name',
        message: 'name字段必须是非空字符串 | name field must be a non-empty string',
        code: 'MISSING_NODE_NAME'
      });
    }

    // 根据节点类型验证特定字段
    if (node.type === 'package') {
      const packageErrors = this.validatePackageNode(node as PackageNode);
      errors.push(...packageErrors.errors);
    } else if (node.type === 'app') {
      const appErrors = this.validateAppNode(node as AppNode);
      errors.push(...appErrors.errors);
    }

    // 验证依赖关系数组
    if (node.dependencies && !Array.isArray(node.dependencies)) {
      errors.push({
        path: 'dependencies',
        message: 'dependencies必须是字符串数组 | dependencies must be an array of strings',
        code: 'INVALID_DEPENDENCIES_TYPE'
      });
    }

    return { valid: errors.length === 0, errors };
  }

  /**
   * 验证包节点
   * Validate package node
   */
  private static validatePackageNode(node: PackageNode): ValidationResult {
    const errors: ValidationError[] = [];

    if (!node.package_dir || typeof node.package_dir !== 'string') {
      errors.push({
        path: 'package_dir',
        message: 'package_dir字段必须是非空字符串 | package_dir field must be a non-empty string',
        code: 'MISSING_PACKAGE_DIR'
      });
    }

    if (!node.package_name || typeof node.package_name !== 'string') {
      errors.push({
        path: 'package_name',
        message: 'package_name字段必须是非空字符串 | package_name field must be a non-empty string',
        code: 'MISSING_PACKAGE_NAME'
      });
    }

    return { valid: errors.length === 0, errors };
  }

  /**
   * 验证应用节点
   * Validate app node
   */
  private static validateAppNode(node: AppNode): ValidationResult {
    const errors: ValidationError[] = [];

    if (!node.app_dir || typeof node.app_dir !== 'string') {
      errors.push({
        path: 'app_dir',
        message: 'app_dir字段必须是非空字符串 | app_dir field must be a non-empty string',
        code: 'MISSING_APP_DIR'
      });
    }

    return { valid: errors.length === 0, errors };
  }

  /**
   * 验证传统配置
   * Validate legacy configuration
   */
  private static validateLegacyConfig(config: LegacyConfig): ValidationResult {
    const errors: ValidationError[] = [];

    if (!config.package_dir || typeof config.package_dir !== 'string') {
      errors.push({
        path: 'package_dir',
        message: 'package_dir字段必须是非空字符串 | package_dir field must be a non-empty string',
        code: 'MISSING_PACKAGE_DIR'
      });
    }

    if (!config.app_dir || typeof config.app_dir !== 'string') {
      errors.push({
        path: 'app_dir',
        message: 'app_dir字段必须是非空字符串 | app_dir field must be a non-empty string',
        code: 'MISSING_APP_DIR'
      });
    }

    if (!config.package_name || typeof config.package_name !== 'string') {
      errors.push({
        path: 'package_name',
        message: 'package_name字段必须是非空字符串 | package_name field must be a non-empty string',
        code: 'MISSING_PACKAGE_NAME'
      });
    }

    return { valid: errors.length === 0, errors };
  }

  /**
   * 验证依赖关系
   * Validate dependencies
   */
  private static validateDependencies(chain: ChainNode[], nodeNames: string[]): ValidationResult {
    const errors: ValidationError[] = [];

    chain.forEach((node, index) => {
      if (node.dependencies) {
        node.dependencies.forEach((depName, depIndex) => {
          // 检查依赖是否存在
          if (!nodeNames.includes(depName)) {
            errors.push({
              path: `chain[${index}].dependencies[${depIndex}]`,
              message: `未知的依赖: ${depName} | Unknown dependency: ${depName}`,
              code: 'UNKNOWN_DEPENDENCY'
            });
          }

          // 检查循环依赖（简单检查：依赖不能指向后面的节点）
          const depNodeIndex = chain.findIndex(n => n.name === depName);
          if (depNodeIndex >= index) {
            errors.push({
              path: `chain[${index}].dependencies[${depIndex}]`,
              message: `无效的依赖顺序: 节点 ${node.name} (位置${index}) 不能依赖位置 ${depNodeIndex} 的节点 ${depName} | Invalid dependency order: node ${node.name} (position ${index}) cannot depend on node ${depName} at position ${depNodeIndex}`,
              code: 'INVALID_DEPENDENCY_ORDER'
            });
          }
        });
      }
    });

    return { valid: errors.length === 0, errors };
  }
}