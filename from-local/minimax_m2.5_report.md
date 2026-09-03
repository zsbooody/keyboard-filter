# MiniMax M2.5 (free) 模型实际效果汇总报告

> 生成日期：2026年3月25日

## 一、模型基本信息

| 属性 | 详情 |
|------|------|
| 模型名称 | MiniMax M2.5 (minimax-m2.5:free) |
| 发布公司 | MiniMax（稀宇科技） |
| 发布时间 | 2026年2月12日 |
| 架构 | MoE（混合专家） |
| 总参数量 | 2290亿 (230B) |
| 激活参数 | 100亿 (10B) |
| 上下文长度 | 128K / 196,608 tokens |
| 最大输出长度 | 196,608 tokens |
| 开源协议 | Modified MIT License（可免费商用） |
| 可用平台 | OpenRouter、302.AI、MiniMax Agent |

---

## 二、基准测试得分

### 2.1 核心基准测试

| 基准测试 | 得分 | 说明 |
|----------|------|------|
| SWE-Bench Verified | 80.2% | 代码开发能力，行业领先 |
| Multi-SWE-Bench | 51.3% | 多仓库复杂场景 |
| BrowseComp | 76.3% | 网页搜索与工具调用 |
| BFCL | 76.8% | 函数调用能力，行业第一 |
| Pinch Bench | 87.80% | 综合能力 |
| GPQA Diamond | 85.20% | 科学知识 |

### 2.2 与其他模型对比

| 对比维度 | MiniMax M2.5 | GLM-5 | 优势方 |
|----------|--------------|-------|--------|
| SWE-Bench 编码 | 80.2% | 77.8% | M2.5 领先 2.4% |
| AIME 数学推理 | - | 92.7% | GLM-5 擅长 |
| BFCL 工具调用 | 76.8% | - | M2.5 行业第一 |
| BrowseComp 搜索 | 76.3% | 75.9% | 基本持平 |
| 输出速度 | 50-100 TPS | ~66 TPS | M2.5 Lightning 更快 |
| 总参数量 | 230B | 744B | GLM-5 更大 |
| 激活参数量 | 10B | 40B | M2.5 更轻量 |

---

## 三、核心能力分析

### 3.1 编程能力

- **支持语言**：Python、Java、JavaScript、Go、Rust、C、C++、TypeScript 等10+种编程语言
- **覆盖场景**：从系统架构设计到代码审查的全流程研发工作
- **实测表现**：
  - 代码生成功能完整度：94.4%
  - 代码质量评分：8.7/10
  - 能够独立完成从需求到交互的全流程开发
  - 在 Web 开发、小程序、3D 场景原型等任务中表现优秀

### 3.2 工具调用与 Agent 能力

- **BFCL 得分 76.8%**：行业领先，精准进行函数调用、文件操作、API 交互
- **BrowseComp 得分 76.3%**：网页搜索和工具使用能力突出
- **任务执行**：相比前代 M2.1，完成任务速度提升 37%，工具调用轮次减少

### 3.3 办公自动化

- 支持 Word、PowerPoint、Excel 文件的生成与操作
- 能够在不同软件环境间进行上下文切换
- 支持多智能体和人与智能体团队协作

### 3.4 特殊能力：Spec-Writing

- 在编写代码之前会像架构师一样进行设计和规划
- 主动分解和规划项目的功能、结构和 UI 设计
- 这一能力是在训练过程中自然涌现的

---

## 四、价格与成本

### 4.1 API 定价（OpenRouter/302.AI）

| 版本 | 输入价格 | 输出价格 |
|------|----------|----------|
| 标准版 | $0.30 / 1M tokens | $1.20 / 1M tokens |
| 加速版 (Lightning) | $0.15 / 1M tokens | $1.20 / 1M tokens |

### 4.2 成本优势

- 相比 Claude Opus：成本仅为其 1/10 到 1/20
- 相比 GLM-5：输出价格仅为 GLM-5 的 37%
- 推理速度：标准版 50 TPS，Lightning 版可达 100 TPS（最快的前沿模型之一）

---

## 五、优势总结

### 5.1 核心优势

1. **性能对标闭源顶尖模型**：SWE-Bench 80.2% 超越 GPT-5.2，接近 Claude Opus 4.6
2. **极致性价比**：成本仅为闭源模型的 1/10
3. **开源可商用**：MIT 协议，可自由部署和定制
4. **推理效率高**：激活参数仅 10B，部署门槛低
5. **工具调用领先**：BFCL 76.8% 行业第一

### 5.2 实际应用案例

- 全公司 30% 的任务由 M2.5 自主完成（MiniMax 内部使用）
- 覆盖研发、产品、销售、人力资源和财务等场景
- 80% 的新提交代码由 M2.5 生成

---

## 六、劣势与局限

### 6.1 已识别问题

1. **推理数学能力**：不如 GLM-5（AIME 92.7% vs M2.5 未披露）
2. **人类直觉与审美**：在模糊需求场景、审美判断方面仍有局限
3. **意图理解**：部分用户反馈不如 Claude Sonnet 和 Opus 对"意图"的理解
4. **复杂场景**：对于模糊需求，处理不够灵活，需要更多人工指导

### 6.2 用户反馈（Reddit）

- "在质量、速度、成本和授权方面达到了最好的平衡"
- "不错，但还不如 Sonnet"
- "在 OpenRouter 上是真的快"

---

## 七、适用场景建议

| 场景 | 推荐模型 | 理由 |
|------|----------|------|
| 高频工具调用和自动编码 | MiniMax M2.5 | BFCL 76.8% 行业第一 |
| 复杂决策和长期规划 | GLM-5 | 推理能力强 |
| 追求性价比 | MiniMax M2.5 | 价格仅为竞品 1/10 |
| 数学证明、高阶推理 | GLM-5 | AIME 92.7% |
| 生产环境快速迭代 | MiniMax M2.5 | 100 TPS 最快速度 |

---

## 八、技术架构亮点

1. **MoE 架构优化**：仅激活 10B 参数（总量的 4.3%），推理效率极高
2. **大规模强化学习**：在超 20 万个真实业务场景中训练
3. **树结构合并策略**：训练样本合并实现约 40 倍训练加速
4. **CISPO 算法**：确保 MoE 模型大规模训练的稳定性
5. **过程奖励机制**：解决 Agent 长上下文中的信用分配问题

---

## 九、总结

MiniMax M2.5 是一个**面向工程和智能体生产力**的开源大模型，在编程和工具调用领域达到了行业顶尖水平。它的出现标志着：

1. **开源权重模型在性能上首次超越闭源模型**（SWE-Bench 80.2%）
2. **成本革命**：让"不用担心成本的前沿模型"成为现实
3. **选择扩大**：企业不再需要默认选择闭源模型

对于需要**高性价比编程能力、智能体自动化、办公自动化**的场景，MiniMax M2.5 是一个务实且强大的选择。

---

## 参考来源

- [MiniMax M2.5 官方公告](https://minimax.io/news/minimax-m25)
- [Design for Online 评测](https://designforonline.com/ai-models/minimax-minimax-m2-5-free/)
- [302.AI 基准实验室实测](https://302.ai/blog/302-ai-benchmark-lab-review-on-minimax-m2-5/)
- [DataLearnerAI 模型详情](http://www.datalearner.com/ai-models/pretrained-models/minimax-m2-5)
- [MiniMax M2.5 vs GLM-5 对比分析](https://help.apiyi.com/minimax-m2-5-vs-glm-5-coding-reasoning-comparison.html)
- [开源 vs 闭源格局分析](https://jangwook.net/zh/blog/zh/minimax-m25-open-weight-vs-proprietary/)
- [Reddit r/LocalLLaMA 讨论](https://www.reddit.com/r/LocalLLaMA/comments/1r3s8mq/is_minimax_m25_the_best_coding_model_in_the_world/)
