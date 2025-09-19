/**
 * 依赖解析器测试套件
 * 
 * 测试拓扑排序和循环依赖检测的各种场景
 */

const { DependencyResolver, resolveBuildOrder } = require('../src/dependency-resolver');
const { GraphUtils } = require('../src/utils/graph-utils');

// 简单的测试框架
class TestRunner {
    constructor() {
        this.testCount = 0;
        this.passCount = 0;
        this.failCount = 0;
    }

    assert(condition, message) {
        this.testCount++;
        if (condition) {
            this.passCount++;
            console.log(`✅ ${message}`);
        } else {
            this.failCount++;
            console.log(`❌ ${message}`);
        }
    }

    assertEqual(actual, expected, message) {
        const condition = JSON.stringify(actual) === JSON.stringify(expected);
        this.assert(condition, 
            message + (condition ? '' : `\n   Expected: ${JSON.stringify(expected)}\n   Actual: ${JSON.stringify(actual)}`));
    }

    printSummary() {
        console.log(`\n=== 测试总结 ===`);
        console.log(`总测试数: ${this.testCount}`);
        console.log(`通过: ${this.passCount}`);
        console.log(`失败: ${this.failCount}`);
        console.log(`成功率: ${((this.passCount / this.testCount) * 100).toFixed(1)}%`);
    }
}

const test = new TestRunner();

// 测试数据
const testCases = {
    // 1. 简单线性依赖: A → B → C
    linear: {
        packages: {
            'pkg-a': { dependencies: [] },
            'pkg-b': { dependencies: ['pkg-a'] },
            'pkg-c': { dependencies: ['pkg-b'] }
        },
        expectedOrder: ['pkg-a', 'pkg-b', 'pkg-c']
    },

    // 2. 分支依赖: A → B, A → C
    branch: {
        packages: {
            'pkg-a': { dependencies: [] },
            'pkg-b': { dependencies: ['pkg-a'] },
            'pkg-c': { dependencies: ['pkg-a'] }
        },
        expectedOrder: ['pkg-a'] // B 和 C 的顺序可以任意
    },

    // 3. 汇聚依赖: B → A, C → A
    converge: {
        packages: {
            'pkg-a': { dependencies: ['pkg-b', 'pkg-c'] },
            'pkg-b': { dependencies: [] },
            'pkg-c': { dependencies: [] }
        },
        expectedOrder: ['pkg-b', 'pkg-c', 'pkg-a']
    },

    // 4. 复杂图: 多层次混合依赖
    complex: {
        packages: {
            'base': { dependencies: [] },
            'utils': { dependencies: ['base'] },
            'auth': { dependencies: ['base', 'utils'] },
            'api': { dependencies: ['auth'] },
            'ui': { dependencies: ['utils'] },
            'app': { dependencies: ['api', 'ui'] }
        }
    },

    // 5. 循环依赖: A → B → C → A
    circular: {
        packages: {
            'pkg-a': { dependencies: ['pkg-c'] },
            'pkg-b': { dependencies: ['pkg-a'] },
            'pkg-c': { dependencies: ['pkg-b'] }
        },
        shouldFail: true
    },

    // 6. 自依赖: A → A
    selfDep: {
        packages: {
            'pkg-a': { dependencies: ['pkg-a'] }
        },
        shouldFail: true
    },

    // 7. 缺失依赖: A → 不存在的包
    missingDep: {
        packages: {
            'pkg-a': { dependencies: ['nonexistent'] }
        },
        shouldFail: true
    },

    // 8. 空包集合
    empty: {
        packages: {},
        expectedOrder: []
    },

    // 9. 单包无依赖
    single: {
        packages: {
            'only-pkg': { dependencies: [] }
        },
        expectedOrder: ['only-pkg']
    },

    // 10. 大规模依赖图
    largScale: generateLargeScaleTest(20)
};

function generateLargeScaleTest(size) {
    const packages = {};
    
    // 创建一个层次结构：每层依赖前一层的所有包
    for (let layer = 0; layer < 5; layer++) {
        for (let i = 0; i < size / 5; i++) {
            const pkgName = `layer${layer}-pkg${i}`;
            const dependencies = [];
            
            // 依赖前一层的包
            if (layer > 0) {
                for (let j = 0; j < size / 5; j++) {
                    dependencies.push(`layer${layer-1}-pkg${j}`);
                }
            }
            
            packages[pkgName] = { dependencies };
        }
    }
    
    return { packages };
}

// 执行测试
console.log('开始依赖解析器测试...\n');

// 测试 1: 简单线性依赖
console.log('=== 测试 1: 简单线性依赖 ===');
const linearResult = resolveBuildOrder(testCases.linear.packages);
test.assert(linearResult.success, '线性依赖解析应该成功');
if (linearResult.success) {
    test.assertEqual(linearResult.buildOrder, testCases.linear.expectedOrder, '线性依赖构建顺序正确');
}

// 测试 2: 分支依赖
console.log('\n=== 测试 2: 分支依赖 ===');
const branchResult = resolveBuildOrder(testCases.branch.packages);
test.assert(branchResult.success, '分支依赖解析应该成功');
if (branchResult.success) {
    test.assert(branchResult.buildOrder[0] === 'pkg-a', '分支依赖中基础包应该排在第一位');
    test.assert(branchResult.buildOrder.includes('pkg-b'), '分支依赖包含所有包');
    test.assert(branchResult.buildOrder.includes('pkg-c'), '分支依赖包含所有包');
}

// 测试 3: 汇聚依赖
console.log('\n=== 测试 3: 汇聚依赖 ===');
const convergeResult = resolveBuildOrder(testCases.converge.packages);
test.assert(convergeResult.success, '汇聚依赖解析应该成功');
if (convergeResult.success) {
    const aIndex = convergeResult.buildOrder.indexOf('pkg-a');
    const bIndex = convergeResult.buildOrder.indexOf('pkg-b');
    const cIndex = convergeResult.buildOrder.indexOf('pkg-c');
    test.assert(aIndex > bIndex && aIndex > cIndex, '汇聚依赖中依赖包应该在目标包之前');
}

// 测试 4: 复杂图
console.log('\n=== 测试 4: 复杂依赖图 ===');
const complexResult = resolveBuildOrder(testCases.complex.packages);
test.assert(complexResult.success, '复杂依赖图解析应该成功');
if (complexResult.success) {
    const order = complexResult.buildOrder;
    const baseIndex = order.indexOf('base');
    const utilsIndex = order.indexOf('utils');
    const authIndex = order.indexOf('auth');
    const apiIndex = order.indexOf('api');
    const uiIndex = order.indexOf('ui');
    const appIndex = order.indexOf('app');
    
    test.assert(baseIndex < utilsIndex, 'base 应该在 utils 之前');
    test.assert(utilsIndex < authIndex, 'utils 应该在 auth 之前');
    test.assert(authIndex < apiIndex, 'auth 应该在 api 之前');
    test.assert(utilsIndex < uiIndex, 'utils 应该在 ui 之前');
    test.assert(apiIndex < appIndex && uiIndex < appIndex, 'app 应该最后构建');
}

// 测试 5: 循环依赖检测
console.log('\n=== 测试 5: 循环依赖检测 ===');
const circularResult = resolveBuildOrder(testCases.circular.packages);
test.assert(!circularResult.success, '循环依赖应该被检测到');
test.assert(circularResult.error && circularResult.error.includes('Circular dependency'), '应该报告循环依赖错误');

// 测试 6: 自依赖检测
console.log('\n=== 测试 6: 自依赖检测 ===');
const selfDepResult = resolveBuildOrder(testCases.selfDep.packages);
test.assert(!selfDepResult.success, '自依赖应该被检测到');

// 测试 7: 缺失依赖检测
console.log('\n=== 测试 7: 缺失依赖检测 ===');
const missingDepResult = resolveBuildOrder(testCases.missingDep.packages);
test.assert(!missingDepResult.success, '缺失依赖应该被检测到');
test.assert(missingDepResult.error && missingDepResult.error.includes('Missing dependencies'), '应该报告缺失依赖错误');

// 测试 8: 空包集合
console.log('\n=== 测试 8: 空包集合 ===');
const emptyResult = resolveBuildOrder(testCases.empty.packages);
test.assert(emptyResult.success, '空包集合应该成功处理');
test.assertEqual(emptyResult.buildOrder, [], '空包集合构建顺序应该为空');

// 测试 9: 单包无依赖
console.log('\n=== 测试 9: 单包无依赖 ===');
const singleResult = resolveBuildOrder(testCases.single.packages);
test.assert(singleResult.success, '单包无依赖应该成功处理');
test.assertEqual(singleResult.buildOrder, ['only-pkg'], '单包构建顺序正确');

// 测试 10: 大规模依赖图性能测试
console.log('\n=== 测试 10: 大规模依赖图性能测试 ===');
const startTime = Date.now();
const largeResult = resolveBuildOrder(testCases.largScale.packages);
const endTime = Date.now();
const duration = endTime - startTime;

test.assert(largeResult.success, '大规模依赖图应该成功解析');
test.assert(duration < 1000, `大规模依赖图解析应该在合理时间内完成 (${duration}ms < 1000ms)`);

// 测试 11: GraphUtils 辅助功能
console.log('\n=== 测试 11: GraphUtils 辅助功能 ===');
const stats = GraphUtils.analyzeGraphStatistics(testCases.complex.packages);
test.assert(stats.totalPackages === 6, 'GraphUtils 统计包数量正确');
test.assert(stats.totalDependencies > 0, 'GraphUtils 统计依赖数量正确');

const depths = GraphUtils.calculateDependencyDepths(testCases.complex.packages);
test.assert(depths.get('base') === 0, 'GraphUtils 计算基础包深度正确');
test.assert(depths.get('app') > 0, 'GraphUtils 计算最终包深度正确');

// 测试 12: 拓扑排序验证
console.log('\n=== 测试 12: 拓扑排序验证 ===');
if (complexResult.success) {
    const validation = GraphUtils.validateTopologicalOrder(complexResult.buildOrder, testCases.complex.packages);
    test.assert(validation.valid, '拓扑排序结果验证通过');
    test.assert(validation.violations.length === 0, '拓扑排序无违反约束');
}

// 测试 13: 边界情况
console.log('\n=== 测试 13: 边界情况测试 ===');

// 无效输入
const invalidResult1 = resolveBuildOrder(null);
test.assert(!invalidResult1.success, '空输入应该被拒绝');

const invalidResult2 = resolveBuildOrder('invalid');
test.assert(!invalidResult2.success, '无效类型输入应该被拒绝');

// 包含空依赖数组
const emptyDepsResult = resolveBuildOrder({
    'pkg-a': { dependencies: [] },
    'pkg-b': { dependencies: ['pkg-a'] },
    'pkg-c': { dependencies: [] }
});
test.assert(emptyDepsResult.success, '包含空依赖数组的包应该正常处理');

// 包含非字符串依赖
const invalidDepsResult = resolveBuildOrder({
    'pkg-a': { dependencies: [null, '', 'pkg-b'] },
    'pkg-b': { dependencies: [] }
});
test.assert(invalidDepsResult.success, '过滤非字符串依赖后应该成功');

test.printSummary();

// 如果是直接运行（非 require），执行测试
if (require.main === module) {
    console.log('\n依赖解析器测试完成。');
}