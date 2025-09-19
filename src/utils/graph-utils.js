/**
 * 图形工具类 - 依赖图分析和可视化辅助函数
 * 
 * 提供图论相关的实用工具函数，支持依赖解析器的高级功能
 */

class GraphUtils {
    /**
     * 计算图的强连通分量（用于检测复杂循环依赖）
     * @param {Map} graph - 依赖图
     * @returns {Array} 强连通分量数组
     */
    static findStronglyConnectedComponents(graph) {
        const visited = new Set();
        const stack = [];
        const components = [];

        // 第一次 DFS - 填充栈
        const dfs1 = (node) => {
            visited.add(node);
            const neighbors = graph.get(node) || [];
            for (const neighbor of neighbors) {
                if (!visited.has(neighbor)) {
                    dfs1(neighbor);
                }
            }
            stack.push(node);
        };

        // 构建反向图
        const reverseGraph = this.buildReverseGraph(graph);

        // 对所有未访问的节点执行第一次 DFS
        for (const node of graph.keys()) {
            if (!visited.has(node)) {
                dfs1(node);
            }
        }

        // 第二次 DFS - 在反向图上找强连通分量
        visited.clear();
        const dfs2 = (node, component) => {
            visited.add(node);
            component.push(node);
            const neighbors = reverseGraph.get(node) || [];
            for (const neighbor of neighbors) {
                if (!visited.has(neighbor)) {
                    dfs2(neighbor, component);
                }
            }
        };

        while (stack.length > 0) {
            const node = stack.pop();
            if (!visited.has(node)) {
                const component = [];
                dfs2(node, component);
                components.push(component);
            }
        }

        return components;
    }

    /**
     * 构建反向图
     * @param {Map} graph - 原始图
     * @returns {Map} 反向图
     */
    static buildReverseGraph(graph) {
        const reverseGraph = new Map();

        // 初始化所有节点
        for (const node of graph.keys()) {
            reverseGraph.set(node, []);
        }

        // 反向所有边
        for (const [node, neighbors] of graph.entries()) {
            for (const neighbor of neighbors) {
                if (!reverseGraph.has(neighbor)) {
                    reverseGraph.set(neighbor, []);
                }
                reverseGraph.get(neighbor).push(node);
            }
        }

        return reverseGraph;
    }

    /**
     * 计算每个包的依赖深度
     * @param {Object} packages - 包配置
     * @returns {Map} 包名到深度的映射
     */
    static calculateDependencyDepths(packages) {
        const depths = new Map();
        const visited = new Set();

        const calculateDepth = (packageName, visiting = new Set()) => {
            if (depths.has(packageName)) {
                return depths.get(packageName);
            }

            if (visiting.has(packageName)) {
                // 检测到循环依赖
                return -1;
            }

            visiting.add(packageName);
            const config = packages[packageName] || {};
            const dependencies = config.dependencies || [];

            if (dependencies.length === 0) {
                depths.set(packageName, 0);
                visiting.delete(packageName);
                return 0;
            }

            let maxDepth = 0;
            for (const dep of dependencies) {
                const depDepth = calculateDepth(dep, visiting);
                if (depDepth === -1) {
                    // 传播循环依赖标记
                    visiting.delete(packageName);
                    return -1;
                }
                maxDepth = Math.max(maxDepth, depDepth + 1);
            }

            depths.set(packageName, maxDepth);
            visiting.delete(packageName);
            return maxDepth;
        };

        for (const packageName of Object.keys(packages)) {
            if (!visited.has(packageName)) {
                calculateDepth(packageName);
                visited.add(packageName);
            }
        }

        return depths;
    }

    /**
     * 查找所有可能的循环依赖路径
     * @param {Object} packages - 包配置
     * @returns {Array} 循环依赖路径数组
     */
    static findAllCycles(packages) {
        const cycles = [];
        const visited = new Set();
        const path = [];
        const pathSet = new Set();

        const dfs = (packageName) => {
            if (pathSet.has(packageName)) {
                // 发现循环
                const cycleStart = path.indexOf(packageName);
                const cycle = path.slice(cycleStart).concat([packageName]);
                cycles.push([...cycle]);
                return;
            }

            if (visited.has(packageName)) {
                return;
            }

            visited.add(packageName);
            path.push(packageName);
            pathSet.add(packageName);

            const config = packages[packageName] || {};
            const dependencies = config.dependencies || [];

            for (const dep of dependencies) {
                if (packages.hasOwnProperty(dep)) {
                    dfs(dep);
                }
            }

            path.pop();
            pathSet.delete(packageName);
        };

        for (const packageName of Object.keys(packages)) {
            if (!visited.has(packageName)) {
                dfs(packageName);
            }
        }

        return cycles;
    }

    /**
     * 生成图的 DOT 格式表示（用于可视化）
     * @param {Object} packages - 包配置
     * @param {Object} options - 可选配置
     * @returns {string} DOT 格式字符串
     */
    static generateDotFormat(packages, options = {}) {
        const {
            highlightCycles = false,
            showDepth = false,
            rankdir = 'TB'  // 'TB' | 'LR' | 'BT' | 'RL'
        } = options;

        let dot = `digraph DependencyGraph {\n`;
        dot += `  rankdir=${rankdir};\n`;
        dot += `  node [shape=box, style=rounded];\n\n`;

        // 如果需要显示深度，计算深度信息
        let depths = null;
        if (showDepth) {
            depths = this.calculateDependencyDepths(packages);
        }

        // 添加节点
        for (const packageName of Object.keys(packages)) {
            let label = packageName;
            let style = '';

            if (showDepth && depths) {
                const depth = depths.get(packageName);
                label += `\\n(depth: ${depth >= 0 ? depth : '∞'})`;
                
                if (depth === -1) {
                    style = ', fillcolor=lightcoral, style="rounded,filled"';
                }
            }

            dot += `  "${packageName}" [label="${label}"${style}];\n`;
        }

        dot += '\n';

        // 添加边
        const cycles = highlightCycles ? this.findAllCycles(packages) : [];
        const cycleEdges = new Set();

        if (highlightCycles) {
            for (const cycle of cycles) {
                for (let i = 0; i < cycle.length - 1; i++) {
                    cycleEdges.add(`${cycle[i]}->${cycle[i + 1]}`);
                }
            }
        }

        for (const [packageName, config] of Object.entries(packages)) {
            const dependencies = config.dependencies || [];
            for (const dep of dependencies) {
                if (packages.hasOwnProperty(dep)) {
                    const edgeKey = `${packageName}->${dep}`;
                    const style = cycleEdges.has(edgeKey) ? 
                        ' [color=red, penwidth=2]' : '';
                    dot += `  "${packageName}" -> "${dep}"${style};\n`;
                }
            }
        }

        dot += '}\n';
        return dot;
    }

    /**
     * 分析依赖图的统计信息
     * @param {Object} packages - 包配置
     * @returns {Object} 统计信息对象
     */
    static analyzeGraphStatistics(packages) {
        const totalPackages = Object.keys(packages).length;
        let totalDependencies = 0;
        let maxDependenciesPerPackage = 0;
        let packagesWithDependencies = 0;

        const inDegree = new Map();  // 被依赖次数
        const outDegree = new Map(); // 依赖其他包的次数

        // 初始化度数统计
        for (const packageName of Object.keys(packages)) {
            inDegree.set(packageName, 0);
            outDegree.set(packageName, 0);
        }

        // 计算依赖统计
        for (const [packageName, config] of Object.entries(packages)) {
            const dependencies = config.dependencies || [];
            const depCount = dependencies.length;

            if (depCount > 0) {
                packagesWithDependencies++;
                totalDependencies += depCount;
                maxDependenciesPerPackage = Math.max(maxDependenciesPerPackage, depCount);
                outDegree.set(packageName, depCount);
            }

            // 更新被依赖计数
            for (const dep of dependencies) {
                if (packages.hasOwnProperty(dep)) {
                    inDegree.set(dep, inDegree.get(dep) + 1);
                }
            }
        }

        // 找到关键包（被依赖最多的包）
        const keyPackages = [];
        let maxInDegree = 0;
        for (const [packageName, degree] of inDegree.entries()) {
            if (degree > maxInDegree) {
                maxInDegree = degree;
                keyPackages.length = 0;
                keyPackages.push(packageName);
            } else if (degree === maxInDegree && degree > 0) {
                keyPackages.push(packageName);
            }
        }

        // 计算连接密度
        const maxPossibleEdges = totalPackages * (totalPackages - 1);
        const density = maxPossibleEdges > 0 ? totalDependencies / maxPossibleEdges : 0;

        return {
            totalPackages,
            totalDependencies,
            averageDependenciesPerPackage: packagesWithDependencies > 0 ? 
                totalDependencies / packagesWithDependencies : 0,
            maxDependenciesPerPackage,
            packagesWithDependencies,
            packagesWithoutDependencies: totalPackages - packagesWithDependencies,
            keyPackages,
            maxInDegree,
            density,
            inDegreeDistribution: Array.from(inDegree.entries()),
            outDegreeDistribution: Array.from(outDegree.entries())
        };
    }

    /**
     * 验证拓扑排序结果的正确性
     * @param {Array} buildOrder - 构建顺序
     * @param {Object} packages - 包配置
     * @returns {Object} 验证结果
     */
    static validateTopologicalOrder(buildOrder, packages) {
        const position = new Map();
        
        // 记录每个包在构建顺序中的位置
        buildOrder.forEach((packageName, index) => {
            position.set(packageName, index);
        });

        const violations = [];

        // 检查每个依赖关系是否符合拓扑顺序
        for (const [packageName, config] of Object.entries(packages)) {
            const dependencies = config.dependencies || [];
            const packagePos = position.get(packageName);

            if (packagePos === undefined) {
                violations.push({
                    type: 'missing_package',
                    package: packageName,
                    message: `Package '${packageName}' not found in build order`
                });
                continue;
            }

            for (const dep of dependencies) {
                const depPos = position.get(dep);
                if (depPos === undefined) {
                    violations.push({
                        type: 'missing_dependency',
                        package: packageName,
                        dependency: dep,
                        message: `Dependency '${dep}' not found in build order`
                    });
                } else if (depPos >= packagePos) {
                    violations.push({
                        type: 'order_violation',
                        package: packageName,
                        dependency: dep,
                        message: `Package '${packageName}' should be built after its dependency '${dep}'`
                    });
                }
            }
        }

        return {
            valid: violations.length === 0,
            violations
        };
    }
}

module.exports = {
    GraphUtils
};