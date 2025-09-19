/**
 * 依赖解析器 - 核心算法实现
 * 
 * 使用深度优先搜索实现拓扑排序和循环依赖检测
 * 时间复杂度: O(V + E)，其中 V 是包数量，E 是依赖关系数量
 */

const { GraphUtils } = require('./utils/graph-utils');

/**
 * 访问状态枚举
 */
const VisitState = {
    UNVISITED: 0,     // 未访问
    TEMP_MARK: 1,     // 临时标记（正在访问中）
    PERM_MARK: 2      // 永久标记（已完成访问）
};

class DependencyResolver {
    constructor() {
        this.visitStates = new Map();
        this.buildOrder = [];
        this.cyclePath = [];
        this.graphUtils = new GraphUtils();
    }

    /**
     * 解析构建顺序的主函数
     * @param {Object} packagesConfig - 包配置对象
     * @returns {Object} 包含 success, buildOrder, error 的结果对象
     */
    resolveBuildOrder(packagesConfig) {
        try {
            // 输入验证
            if (!packagesConfig || typeof packagesConfig !== 'object') {
                return {
                    success: false,
                    error: 'Invalid packages configuration: must be an object'
                };
            }

            const packages = packagesConfig.packages || packagesConfig;
            if (!packages || typeof packages !== 'object') {
                return {
                    success: false,
                    error: 'No packages found in configuration'
                };
            }

            // 重置状态
            this.reset();

            // 构建依赖图
            const graph = this.buildDependencyGraph(packages);
            
            // 验证依赖关系
            const validationResult = this.validateDependencies(packages, graph);
            if (!validationResult.success) {
                return validationResult;
            }

            // 执行拓扑排序
            const sortResult = this.topologicalSort(packages, graph);
            if (!sortResult.success) {
                return sortResult;
            }

            return {
                success: true,
                buildOrder: this.buildOrder,
                dependencyGraph: graph
            };

        } catch (error) {
            return {
                success: false,
                error: `Unexpected error during dependency resolution: ${error.message}`
            };
        }
    }

    /**
     * 重置内部状态
     */
    reset() {
        this.visitStates.clear();
        this.buildOrder = [];
        this.cyclePath = [];
    }

    /**
     * 构建依赖图
     * @param {Object} packages - 包配置
     * @returns {Map} 依赖图的邻接表表示
     */
    buildDependencyGraph(packages) {
        const graph = new Map();
        
        // 初始化所有包节点
        for (const packageName of Object.keys(packages)) {
            if (!graph.has(packageName)) {
                graph.set(packageName, []);
            }
        }

        // 添加依赖边
        for (const [packageName, config] of Object.entries(packages)) {
            const dependencies = config.dependencies || [];
            
            if (Array.isArray(dependencies)) {
                for (const dep of dependencies) {
                    if (typeof dep === 'string' && dep.trim()) {
                        if (!graph.has(dep)) {
                            graph.set(dep, []);
                        }
                        graph.get(dep).push(packageName);
                    }
                }
            }
        }

        return graph;
    }

    /**
     * 验证依赖关系
     * @param {Object} packages - 包配置
     * @param {Map} graph - 依赖图
     * @returns {Object} 验证结果
     */
    validateDependencies(packages, graph) {
        const missingDeps = [];
        
        for (const [packageName, config] of Object.entries(packages)) {
            const dependencies = config.dependencies || [];
            
            for (const dep of dependencies) {
                if (typeof dep === 'string' && dep.trim()) {
                    if (!packages.hasOwnProperty(dep)) {
                        missingDeps.push({
                            package: packageName,
                            missingDependency: dep
                        });
                    }
                }
            }
        }

        if (missingDeps.length > 0) {
            const errorMsg = 'Missing dependencies detected:\n' + 
                missingDeps.map(item => `  - Package '${item.package}' depends on undefined package '${item.missingDependency}'`)
                .join('\n');
            
            return {
                success: false,
                error: errorMsg,
                missingDependencies: missingDeps
            };
        }

        return { success: true };
    }

    /**
     * 拓扑排序实现
     * @param {Object} packages - 包配置
     * @param {Map} graph - 依赖图
     * @returns {Object} 排序结果
     */
    topologicalSort(packages, graph) {
        // 初始化所有节点为未访问状态
        for (const packageName of Object.keys(packages)) {
            this.visitStates.set(packageName, VisitState.UNVISITED);
        }

        // 对每个未访问的节点执行 DFS
        for (const packageName of Object.keys(packages)) {
            if (this.visitStates.get(packageName) === VisitState.UNVISITED) {
                const dfsResult = this.dfsVisit(packageName, graph, []);
                if (!dfsResult.success) {
                    return dfsResult;
                }
            }
        }

        // 反转结果得到正确的构建顺序
        this.buildOrder.reverse();

        return { success: true };
    }

    /**
     * 深度优先搜索访问
     * @param {string} packageName - 当前访问的包名
     * @param {Map} graph - 依赖图
     * @param {Array} path - 当前访问路径（用于循环检测）
     * @returns {Object} 访问结果
     */
    dfsVisit(packageName, graph, path) {
        // 检测循环依赖
        if (this.visitStates.get(packageName) === VisitState.TEMP_MARK) {
            // 找到循环依赖，构建循环路径
            const cycleStart = path.indexOf(packageName);
            const cyclePath = path.slice(cycleStart).concat([packageName]);
            
            return {
                success: false,
                error: `Circular dependency detected: ${cyclePath.join(' → ')}`,
                cyclePath: cyclePath
            };
        }

        // 如果已经永久标记，跳过
        if (this.visitStates.get(packageName) === VisitState.PERM_MARK) {
            return { success: true };
        }

        // 标记为临时访问
        this.visitStates.set(packageName, VisitState.TEMP_MARK);
        const newPath = [...path, packageName];

        // 访问所有依赖此包的包
        const dependents = graph.get(packageName) || [];
        for (const dependent of dependents) {
            const result = this.dfsVisit(dependent, graph, newPath);
            if (!result.success) {
                return result;
            }
        }

        // 标记为永久访问并添加到构建顺序
        this.visitStates.set(packageName, VisitState.PERM_MARK);
        this.buildOrder.push(packageName);

        return { success: true };
    }

    /**
     * 获取包的依赖信息
     * @param {Object} packages - 包配置
     * @returns {Object} 依赖信息统计
     */
    getDependencyInfo(packages) {
        const info = {
            totalPackages: Object.keys(packages).length,
            dependencyCount: 0,
            maxDepth: 0,
            rootPackages: [],
            leafPackages: []
        };

        const graph = this.buildDependencyGraph(packages);
        
        // 统计依赖数量
        for (const [packageName, config] of Object.entries(packages)) {
            const deps = config.dependencies || [];
            info.dependencyCount += deps.length;
        }

        // 找到根包（没有依赖的包）和叶包（没有被依赖的包）
        for (const packageName of Object.keys(packages)) {
            const config = packages[packageName];
            const dependencies = config.dependencies || [];
            const dependents = graph.get(packageName) || [];

            if (dependencies.length === 0) {
                info.rootPackages.push(packageName);
            }
            if (dependents.length === 0) {
                info.leafPackages.push(packageName);
            }
        }

        return info;
    }
}

// 便捷的导出函数
function resolveBuildOrder(packagesConfig) {
    const resolver = new DependencyResolver();
    return resolver.resolveBuildOrder(packagesConfig);
}

module.exports = {
    DependencyResolver,
    resolveBuildOrder,
    VisitState
};