/**
 * 依赖错误处理器 - 专门的错误处理和报告模块
 * 
 * 提供详细的错误分析、路径追踪和格式化输出功能
 * 配合dependency-resolver.js使用，增强错误报告能力
 */

/**
 * 错误类型枚举
 */
const ErrorType = {
    CIRCULAR_DEPENDENCY: 'circular_dependency',
    MISSING_DEPENDENCY: 'missing_dependency',
    INVALID_CONFIG: 'invalid_config',
    INVALID_PACKAGE_NAME: 'invalid_package_name',
    INVALID_DEPENDENCY_FORMAT: 'invalid_dependency_format',
    EMPTY_PACKAGES: 'empty_packages',
    SELF_DEPENDENCY: 'self_dependency'
};

/**
 * 错误严重性级别
 */
const ErrorSeverity = {
    CRITICAL: 'critical',    // 阻止构建的错误
    ERROR: 'error',          // 严重错误
    WARNING: 'warning',      // 警告
    INFO: 'info'            // 信息性提示
};

class DependencyErrorHandler {
    constructor(options = {}) {
        this.maxCyclePathLength = options.maxCyclePathLength || 10;
        this.maxErrorDetails = options.maxErrorDetails || 50;
        this.enableDetailedLogging = options.enableDetailedLogging !== false;
    }

    /**
     * 验证包配置格式
     * @param {any} packagesConfig - 包配置
     * @returns {Object} 验证结果
     */
    validatePackagesConfig(packagesConfig) {
        const errors = [];
        
        // 基本类型检查
        if (!packagesConfig) {
            errors.push(this.createError(
                ErrorType.INVALID_CONFIG,
                ErrorSeverity.CRITICAL,
                'Packages configuration is null or undefined',
                { provided: packagesConfig }
            ));
            return { valid: false, errors };
        }

        if (typeof packagesConfig !== 'object') {
            errors.push(this.createError(
                ErrorType.INVALID_CONFIG,
                ErrorSeverity.CRITICAL,
                `Packages configuration must be an object, got ${typeof packagesConfig}`,
                { provided: packagesConfig, expectedType: 'object' }
            ));
            return { valid: false, errors };
        }

        // 检查是否为空对象
        const packages = packagesConfig.packages || packagesConfig;
        if (!packages || typeof packages !== 'object') {
            errors.push(this.createError(
                ErrorType.INVALID_CONFIG,
                ErrorSeverity.CRITICAL,
                'No valid packages found in configuration',
                { provided: packagesConfig }
            ));
            return { valid: false, errors };
        }

        const packageNames = Object.keys(packages);
        if (packageNames.length === 0) {
            errors.push(this.createError(
                ErrorType.EMPTY_PACKAGES,
                ErrorSeverity.WARNING,
                'No packages defined in configuration',
                { packageCount: 0 }
            ));
            return { valid: false, errors };
        }

        // 验证每个包的配置
        for (const [packageName, config] of Object.entries(packages)) {
            const packageErrors = this.validatePackageConfig(packageName, config, packages);
            errors.push(...packageErrors);
        }

        return {
            valid: errors.filter(e => e.severity === ErrorSeverity.CRITICAL || e.severity === ErrorSeverity.ERROR).length === 0,
            errors,
            warnings: errors.filter(e => e.severity === ErrorSeverity.WARNING),
            packageCount: packageNames.length
        };
    }

    /**
     * 验证单个包配置
     * @param {string} packageName - 包名
     * @param {any} config - 包配置
     * @param {Object} allPackages - 所有包的配置
     * @returns {Array} 错误数组
     */
    validatePackageConfig(packageName, config, allPackages) {
        const errors = [];

        // 验证包名
        if (!packageName || typeof packageName !== 'string') {
            errors.push(this.createError(
                ErrorType.INVALID_PACKAGE_NAME,
                ErrorSeverity.ERROR,
                'Package name must be a non-empty string',
                { providedName: packageName, packageConfig: config }
            ));
            return errors; // 如果包名无效，跳过其他验证
        }

        // 验证包名格式
        if (!/^[a-zA-Z0-9._-]+$/.test(packageName)) {
            errors.push(this.createError(
                ErrorType.INVALID_PACKAGE_NAME,
                ErrorSeverity.WARNING,
                'Package name contains potentially problematic characters',
                { packageName, allowedPattern: '^[a-zA-Z0-9._-]+$' }
            ));
        }

        // 验证配置对象
        if (!config || typeof config !== 'object') {
            errors.push(this.createError(
                ErrorType.INVALID_CONFIG,
                ErrorSeverity.ERROR,
                `Package '${packageName}' configuration must be an object`,
                { packageName, providedConfig: config }
            ));
            return errors;
        }

        // 验证依赖数组
        if (config.dependencies !== undefined) {
            if (!Array.isArray(config.dependencies)) {
                errors.push(this.createError(
                    ErrorType.INVALID_DEPENDENCY_FORMAT,
                    ErrorSeverity.ERROR,
                    `Package '${packageName}' dependencies must be an array`,
                    { 
                        packageName, 
                        providedDependencies: config.dependencies,
                        expectedType: 'Array'
                    }
                ));
            } else {
                // 验证每个依赖项
                config.dependencies.forEach((dep, index) => {
                    const depErrors = this.validateDependency(packageName, dep, index, allPackages);
                    errors.push(...depErrors);
                });
            }
        }

        return errors;
    }

    /**
     * 验证单个依赖项
     * @param {string} packageName - 包名
     * @param {any} dependency - 依赖项
     * @param {number} index - 依赖项索引
     * @param {Object} allPackages - 所有包的配置
     * @returns {Array} 错误数组
     */
    validateDependency(packageName, dependency, index, allPackages) {
        const errors = [];

        // 检查依赖项类型
        if (typeof dependency !== 'string') {
            errors.push(this.createError(
                ErrorType.INVALID_DEPENDENCY_FORMAT,
                ErrorSeverity.ERROR,
                `Package '${packageName}' dependency at index ${index} must be a string`,
                { 
                    packageName, 
                    dependencyIndex: index,
                    providedDependency: dependency,
                    expectedType: 'string'
                }
            ));
            return errors;
        }

        // 检查空字符串
        if (!dependency.trim()) {
            errors.push(this.createError(
                ErrorType.INVALID_DEPENDENCY_FORMAT,
                ErrorSeverity.ERROR,
                `Package '${packageName}' has empty dependency at index ${index}`,
                { packageName, dependencyIndex: index }
            ));
            return errors;
        }

        // 检查自依赖
        if (dependency === packageName) {
            errors.push(this.createError(
                ErrorType.SELF_DEPENDENCY,
                ErrorSeverity.ERROR,
                `Package '${packageName}' cannot depend on itself`,
                { packageName, selfDependency: dependency }
            ));
        }

        // 检查依赖是否存在
        if (!allPackages.hasOwnProperty(dependency)) {
            errors.push(this.createError(
                ErrorType.MISSING_DEPENDENCY,
                ErrorSeverity.ERROR,
                `Package '${packageName}' depends on undefined package '${dependency}'`,
                { 
                    packageName, 
                    missingDependency: dependency,
                    availablePackages: Object.keys(allPackages),
                    suggestions: this.suggestSimilarPackages(dependency, Object.keys(allPackages))
                }
            ));
        }

        return errors;
    }

    /**
     * 创建循环依赖错误报告
     * @param {Array} cyclePath - 循环路径
     * @param {Object} context - 上下文信息
     * @returns {Object} 错误对象
     */
    createCircularDependencyError(cyclePath, context = {}) {
        const truncatedPath = this.truncateCyclePath(cyclePath);
        const pathString = truncatedPath.join(' → ');
        
        return this.createError(
            ErrorType.CIRCULAR_DEPENDENCY,
            ErrorSeverity.CRITICAL,
            `Circular dependency detected: ${pathString}`,
            {
                fullCyclePath: cyclePath,
                displayPath: truncatedPath,
                cycleLength: cyclePath.length,
                isTruncated: cyclePath.length > this.maxCyclePathLength,
                ...context
            }
        );
    }

    /**
     * 创建缺失依赖错误报告
     * @param {Array} missingDeps - 缺失依赖列表
     * @returns {Object} 错误对象
     */
    createMissingDependenciesError(missingDeps) {
        const groupedByPackage = this.groupMissingDependencies(missingDeps);
        const summaryMessage = this.formatMissingDependenciesSummary(groupedByPackage);
        
        return this.createError(
            ErrorType.MISSING_DEPENDENCY,
            ErrorSeverity.CRITICAL,
            'Missing dependencies detected',
            {
                summary: summaryMessage,
                missingDependencies: missingDeps,
                groupedByPackage,
                totalMissing: missingDeps.length,
                affectedPackages: Object.keys(groupedByPackage)
            }
        );
    }

    /**
     * 生成详细的错误报告
     * @param {Array} errors - 错误数组
     * @returns {string} 格式化的错误报告
     */
    generateDetailedReport(errors) {
        if (!errors || errors.length === 0) {
            return 'No errors detected.';
        }

        let report = '\n=== DEPENDENCY ANALYSIS REPORT ===\n\n';
        
        // 按严重性分组
        const errorsBySeverity = this.groupErrorsBySeverity(errors);
        
        // 生成摘要
        report += this.generateErrorSummary(errorsBySeverity);
        
        // 生成详细错误信息
        for (const severity of [ErrorSeverity.CRITICAL, ErrorSeverity.ERROR, ErrorSeverity.WARNING, ErrorSeverity.INFO]) {
            const severityErrors = errorsBySeverity[severity] || [];
            if (severityErrors.length > 0) {
                report += `\n${severity.toUpperCase()} ISSUES (${severityErrors.length}):\n`;
                report += '─'.repeat(50) + '\n';
                
                severityErrors.forEach((error, index) => {
                    report += `${index + 1}. ${this.formatErrorForReport(error)}\n`;
                });
            }
        }
        
        // 添加建议和下一步
        report += this.generateRecommendations(errors);
        
        return report;
    }

    /**
     * 创建标准错误对象
     * @param {string} type - 错误类型
     * @param {string} severity - 严重性
     * @param {string} message - 错误消息
     * @param {Object} details - 详细信息
     * @returns {Object} 错误对象
     */
    createError(type, severity, message, details = {}) {
        return {
            type,
            severity,
            message,
            details,
            timestamp: new Date().toISOString(),
            id: this.generateErrorId(type, message)
        };
    }

    /**
     * 截断循环路径以避免过长输出
     * @param {Array} cyclePath - 循环路径
     * @returns {Array} 截断后的路径
     */
    truncateCyclePath(cyclePath) {
        if (cyclePath.length <= this.maxCyclePathLength) {
            return [...cyclePath];
        }
        
        const half = Math.floor((this.maxCyclePathLength - 1) / 2);
        return [
            ...cyclePath.slice(0, half),
            '...',
            ...cyclePath.slice(-half)
        ];
    }

    /**
     * 建议相似的包名
     * @param {string} target - 目标包名
     * @param {Array} available - 可用包名列表
     * @returns {Array} 建议的包名
     */
    suggestSimilarPackages(target, available) {
        const suggestions = [];
        const targetLower = target.toLowerCase();
        
        for (const pkg of available) {
            const pkgLower = pkg.toLowerCase();
            
            // 编辑距离检查
            if (this.levenshteinDistance(targetLower, pkgLower) <= 2) {
                suggestions.push(pkg);
            }
            // 包含关系检查
            else if (pkgLower.includes(targetLower) || targetLower.includes(pkgLower)) {
                suggestions.push(pkg);
            }
        }
        
        return suggestions.slice(0, 3); // 最多返回3个建议
    }

    /**
     * 计算编辑距离
     * @param {string} a - 字符串a
     * @param {string} b - 字符串b
     * @returns {number} 编辑距离
     */
    levenshteinDistance(a, b) {
        const matrix = [];
        
        for (let i = 0; i <= b.length; i++) {
            matrix[i] = [i];
        }
        
        for (let j = 0; j <= a.length; j++) {
            matrix[0][j] = j;
        }
        
        for (let i = 1; i <= b.length; i++) {
            for (let j = 1; j <= a.length; j++) {
                if (b.charAt(i - 1) === a.charAt(j - 1)) {
                    matrix[i][j] = matrix[i - 1][j - 1];
                } else {
                    matrix[i][j] = Math.min(
                        matrix[i - 1][j - 1] + 1,
                        matrix[i][j - 1] + 1,
                        matrix[i - 1][j] + 1
                    );
                }
            }
        }
        
        return matrix[b.length][a.length];
    }

    /**
     * 按包分组缺失依赖
     * @param {Array} missingDeps - 缺失依赖列表
     * @returns {Object} 按包分组的缺失依赖
     */
    groupMissingDependencies(missingDeps) {
        const grouped = {};
        
        for (const item of missingDeps) {
            if (!grouped[item.package]) {
                grouped[item.package] = [];
            }
            grouped[item.package].push(item.missingDependency);
        }
        
        return grouped;
    }

    /**
     * 格式化缺失依赖摘要
     * @param {Object} groupedByPackage - 按包分组的缺失依赖
     * @returns {string} 格式化的摘要
     */
    formatMissingDependenciesSummary(groupedByPackage) {
        const lines = [];
        
        for (const [packageName, missing] of Object.entries(groupedByPackage)) {
            lines.push(`  - Package '${packageName}' is missing: ${missing.join(', ')}`);
        }
        
        return lines.join('\n');
    }

    /**
     * 按严重性分组错误
     * @param {Array} errors - 错误数组
     * @returns {Object} 按严重性分组的错误
     */
    groupErrorsBySeverity(errors) {
        const grouped = {};
        
        for (const error of errors) {
            if (!grouped[error.severity]) {
                grouped[error.severity] = [];
            }
            grouped[error.severity].push(error);
        }
        
        return grouped;
    }

    /**
     * 生成错误摘要
     * @param {Object} errorsBySeverity - 按严重性分组的错误
     * @returns {string} 错误摘要
     */
    generateErrorSummary(errorsBySeverity) {
        let summary = 'SUMMARY:\n';
        
        const counts = {
            [ErrorSeverity.CRITICAL]: (errorsBySeverity[ErrorSeverity.CRITICAL] || []).length,
            [ErrorSeverity.ERROR]: (errorsBySeverity[ErrorSeverity.ERROR] || []).length,
            [ErrorSeverity.WARNING]: (errorsBySeverity[ErrorSeverity.WARNING] || []).length,
            [ErrorSeverity.INFO]: (errorsBySeverity[ErrorSeverity.INFO] || []).length
        };
        
        summary += `  Critical: ${counts.critical}\n`;
        summary += `  Errors: ${counts.error}\n`;
        summary += `  Warnings: ${counts.warning}\n`;
        summary += `  Info: ${counts.info}\n`;
        
        return summary;
    }

    /**
     * 格式化单个错误用于报告
     * @param {Object} error - 错误对象
     * @returns {string} 格式化的错误描述
     */
    formatErrorForReport(error) {
        let formatted = `[${error.type}] ${error.message}`;
        
        if (this.enableDetailedLogging && error.details && Object.keys(error.details).length > 0) {
            formatted += '\n   Details:';
            for (const [key, value] of Object.entries(error.details)) {
                if (key === 'suggestions' && Array.isArray(value) && value.length > 0) {
                    formatted += `\n     ${key}: ${value.join(', ')}`;
                } else if (typeof value === 'object') {
                    formatted += `\n     ${key}: ${JSON.stringify(value, null, 2).replace(/\n/g, '\n     ')}`;
                } else {
                    formatted += `\n     ${key}: ${value}`;
                }
            }
        }
        
        return formatted;
    }

    /**
     * 生成建议和推荐
     * @param {Array} errors - 错误数组
     * @returns {string} 建议文本
     */
    generateRecommendations(errors) {
        let recommendations = '\n\nRECOMMENDATIONS:\n';
        recommendations += '─'.repeat(50) + '\n';
        
        const errorTypes = new Set(errors.map(e => e.type));
        
        if (errorTypes.has(ErrorType.CIRCULAR_DEPENDENCY)) {
            recommendations += '• Review dependency architecture to eliminate circular references\n';
            recommendations += '• Consider using dependency injection or interface segregation\n';
        }
        
        if (errorTypes.has(ErrorType.MISSING_DEPENDENCY)) {
            recommendations += '• Verify all package names are spelled correctly\n';
            recommendations += '• Check if missing packages need to be added to the configuration\n';
        }
        
        if (errorTypes.has(ErrorType.INVALID_CONFIG)) {
            recommendations += '• Review configuration file format and structure\n';
            recommendations += '• Ensure all required fields are properly defined\n';
        }
        
        recommendations += '• Run validation again after making changes\n';
        
        return recommendations;
    }

    /**
     * 生成错误ID
     * @param {string} type - 错误类型
     * @param {string} message - 错误消息
     * @returns {string} 错误ID
     */
    generateErrorId(type, message) {
        const hash = this.simpleHash(type + message);
        return `${type}_${hash.toString(16).substring(0, 8)}`;
    }

    /**
     * 简单哈希函数
     * @param {string} str - 输入字符串
     * @returns {number} 哈希值
     */
    simpleHash(str) {
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            const char = str.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash; // 转换为32位整数
        }
        return hash;
    }
}

module.exports = {
    DependencyErrorHandler,
    ErrorType,
    ErrorSeverity
};