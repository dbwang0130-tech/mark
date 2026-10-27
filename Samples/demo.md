---
title: 示例文档
tags: [markdown, latex]
---

# Markdown 预览测试

这是一段**粗体**、*斜体*、~~删除线~~、`行内代码` 和 [链接](https://example.com)。自动链接：https://apple.com

> 引用块，包含行内公式 $E = mc^2$ 和 \(a^2 + b^2 = c^2\)。

## 列表

- [x] 已完成任务
- [ ] 未完成任务
  1. 嵌套有序 $\alpha_i$
  2. 价格 $5 和 $10 不应被识别为公式

## 表格

| 语言 | 类型 | 公式 |
|:-----|:----:|-----:|
| Swift | 编译型 | $\sum_{i=1}^n i$ |
| Python | 解释型 | $\sqrt[3]{x}$ |

## 公式

$$
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
$$

$$
f(x) = \begin{cases} x^2 & x \ge 0 \\ -x & x < 0 \end{cases}
$$

$$
\begin{aligned}
\nabla \cdot \mathbf{E} &= \frac{\rho}{\varepsilon_0} \\
\nabla \times \mathbf{B} &= \mu_0 \mathbf{J} + \mu_0\varepsilon_0 \frac{\partial \mathbf{E}}{\partial t}
\end{aligned} \tag{1}
$$

$$
A = \begin{pmatrix} a_{11} & a_{12} \\ a_{21} & a_{22} \end{pmatrix}, \quad
\det A = \left| \begin{matrix} a & b \\ c & d \end{matrix} \right|, \quad
\lim_{n \to \infty} \left(1 + \frac{1}{n}\right)^n = e
$$

\[ \mathbb{R}^n, \mathcal{L}, \mathfrak{g}, \hat{x}, \vec{v}, \overline{AB}, \binom{n}{k}, \underbrace{1+\cdots+1}_{n}, x \xrightarrow{f} y \]

```math
\text{softmax}(z)_i = \frac{e^{z_i}}{\sum_j e^{z_j}}
```

## 代码

```swift
import Foundation

/// 计算斐波那契
@MainActor
func fib(_ n: Int) -> Int {
    guard n > 1 else { return n }   // 递归
    let s = "hello \(n)"
    return fib(n - 1) + fib(n - 2)
}
```

```python
@dataclass
class Point:
    x: float = 0.0
    def norm(self) -> float:
        """模长"""
        return (self.x ** 2) ** 0.5  # comment
```

```javascript
const add = async (a, b) => `${a + b}`;
console.log(add(1, 2), null, 0x1F);
```

```bash
#!/bin/bash
for f in *.md; do
  echo "file: $f ${HOME}"  # 注释
done
```

```json
{ "name": "demo", "version": 1.2, "ok": true, "list": [null, -3e5] }
```

```diff
- old line
+ new line
```

```html
<div class="box" id="a">Hello &amp; <b>world</b><!-- c --></div>
```

```yaml
server:
  port: 8080   # 端口
  host: "localhost"
  debug: true
```

普通代码块：

    indented code $x$

脚注引用[^1]。

[^1]: 这是脚注。

---

<details><summary>折叠内容</summary>隐藏的文字</details>

## 本地图片

![公式截图](formula.png)
