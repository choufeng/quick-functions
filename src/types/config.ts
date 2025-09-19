/**
 * 配置系统类型定义
 * Configuration system type definitions
 */

export interface PackageNode {
  type: 'package';
  name: string;
  package_dir: string;
  package_name: string;
  build_command?: string;
  dependencies?: string[];
}

export interface AppNode {
  type: 'app';
  name: string;
  app_dir: string;
  start_command?: string;
  dependencies?: string[];
}

export type ChainNode = PackageNode | AppNode;

export interface ChainConfig {
  name: string;
  description: string;
  type: 'chain';
  chain: ChainNode[];
}

export interface LegacyConfig {
  name: string;
  description: string;
  package_dir: string;
  app_dir: string;
  package_name: string;
  start_command?: string;
  build_command?: string;
  type?: 'legacy';
}

export type Config = ChainConfig | LegacyConfig;

export interface ConfigFile {
  configs: Config[];
}

// 验证和解析相关的类型
export interface ValidationError {
  path: string;
  message: string;
  code: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
}

export interface ParsedChainNode {
  type: 'package' | 'app';
  name: string;
  package_dir?: string;
  package_name?: string;
  app_dir?: string;
  build_command?: string;
  start_command?: string;
  dependencies: string[];
}

export interface ParsedChainConfig {
  type: 'chain';
  node_count: number;
  nodes: ParsedChainNode[];
}