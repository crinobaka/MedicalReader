MedicalReader v0.1 数据标准设计文档（Data Standard Specification）

版本：v0.1 Draft
标准名称：

> MRDS（MedicalReader Data Standard）



目标：

建立一套开放、可扩展的医学专业书籍知识数据标准。

核心思想：

> PDF只是存储载体，真正可复用的是“知识索引数据”。




---

1. 数据标准设计目标

1.1 解决的问题

医学专业书籍存在：

版本多

章节结构不同

疾病名称不统一

缩写大量存在

中文英文混用

指南与教材关联困难


例如：

一个知识点：

“糖尿病肾病”

可能出现：

Diabetic Kidney Disease

DKD

Diabetic Nephropathy

DN

糖尿病肾病

糖肾

E11.2

普通全文搜索：

很难。

MRDS目标：

输入任意一种：

↓

找到同一个知识节点。


---

2. 数据分层设计

MedicalReader采用五层数据模型：

Layer 5
用户知识层
(Highlight/Note)


Layer 4
书籍定位层
(Page/Chapter)


Layer 3
医学知识层
(Disease/Drug/Concept)


Layer 2
标准映射层
(ICD/Alias)


Layer 1
原始文档层
(PDF/EPUB)


---

3. 数据包结构设计

一本书对应一个Index Package。

例如：

PUMCH_Internal_Medicine_v10/

│
├── metadata.json

├── booktree.json

├── index.mrif

├── dictionary.json

├── checksum.txt

└── README.md


---

4. metadata.json

负责描述书籍。

示例：

{
 "book_id":"CN_MED_INT_10",

 "title":{
   "zh":"协和内科学",
   "en":"PUMCH Internal Medicine"
 },

 "edition":"10",

 "publisher":"",

 "year":2024,


 "language":[
   "zh",
   "en"
 ],


 "file":{
   "name":"source.pdf",
   "pages":2400,
   "hash":"xxxxx"
 },


 "creator":{
   "name":"MedicalReader Community"
 }

}


---

5. booktree.json

作用：

章节树。

解决：

PDF目录混乱。


---

结构：

Book

|

├── Chapter

      |

      ├── Disease

            |

            ├── Diagnosis

            └── Treatment

示例：

{

"id":"ENDO",

"name":"Endocrinology",

"children":[

 {

 "id":"DM",

 "name":"Diabetes Mellitus",

 "page_start":1000,

 "page_end":1150

 }

]

}


---

6. index.mrif核心设计

这是整个项目灵魂。


---

6.1 Knowledge Object

一个医学知识点。

例如：

DKD。

{

"id":"MR_K_DKD_001",


"type":"disease",


"name":{


"en":"Diabetic Kidney Disease",


"zh":"糖尿病肾病"


},


"alias":[

"DKD",

"Diabetic Nephropathy",

"DN",

"糖肾"

]


}


---

7. Knowledge Type设计

第一版支持：

Disease

疾病

例如：

"type":"disease"


---

Drug

药物

例如：

metformin


---

Symptom

症状

例如：

hyperglycemia


---

Examination

检查

例如：

HbA1c


---

Guideline

指南节点

例如：

ADA2025


---

8. Alias系统设计

医学搜索核心。

字段：

alias:[]

例如：

{

"name":"甲状腺功能亢进",

"alias":[

"hyperthyroidism",

"hyperthyroid",

"HT",

"甲亢"

]

}


---

9. HIS式拼音索引

设计：

initial

例如：

甲状腺危象

生成：

jia zhuang xian wei xiang


jzxwx

保存：

{

"name":"甲状腺危象",

"pinyin":{

"full":
"jia zhuang xian wei xiang",

"initial":
"jzxwx"

}

}


---

10. ICD映射

字段：

icd:[]

例如：

{

"name":"Diabetic Kidney Disease",

"icd":[

"E11.2"

]

}

注意：

ICD不是唯一标准。

未来支持：

ICD10

ICD11

SNOMED CT



---

11. Location设计

知识点必须绑定书页。

例如：

{

"knowledge_id":

"MR_K_DKD_001",


"locations":[


{

"book":

"CN_MED_INT_10",


"chapter":

"Diabetes Complications",


"page":

1234


}

]

}


---

12. 搜索索引结构

不要直接搜JSON。

导入SQLite。


---

search_index表

CREATE TABLE search_index(

id TEXT,


keyword TEXT,


type TEXT,


target_id TEXT,


weight INTEGER

);


---

数据：

DKD

↓

Disease

↓

MR_K_DKD_001

weight=10



diabetic nephropathy

weight=8


tnbsb

weight=3


---

13. 搜索词典dictionary.json

用于全局医学词库。

结构：

{

"DKD":{

"expand":[

"Diabetic Kidney Disease",

"E11.2"

]

}

}


---

14. 用户数据标准

用户数据独立。

不要污染索引。

目录：

MedicalReader

|

UserData

|

├── notes

├── highlight

└── bookmark


---

15. Highlight标准

{

"id":"HL001",


"book_id":"CN_MED_INT_10",


"page":1234,


"position":{

"x":100,

"y":200,

"w":300,

"h":50

},


"text":

"DKD diagnostic criteria",


"color":

"yellow"

}


---

16. Note标准

{

"id":"NOTE001",

"target":

{

"book":

"CN_MED_INT_10",

"page":

1234

},


"content":

"重点复习"


}


---

17. 索引制作规范

这是开源项目关键。


---

一个索引贡献者需要提交：

Book_Index_Project

|

├── index.mrif

├── metadata.json

├── booktree.json

└── README.md


---

README：

必须说明：

书名：

版本：

PDF来源：

页码是否一致：

制作人员：

校验状态：


---

18. 索引质量等级

引入评级。

S级

官方维护

100%校验。


---

A级

社区审核。


---

B级

自动生成。


---

C级

实验。


---

显示：

协和内科学

Index Quality:

A


---

19. 防止社区混乱机制

问题：

不同人做同一本书。

解决：

Book ID规则。

格式：

国家_出版社_书名_版本


CN_PUMCH_INTERNAL_MED_10


---

20. 未来扩展

指南融合

例如：

知识节点：

DKD

关联：

教材

指南

论文

病例

形成：

医学知识图谱。


---

21. 第一批官方索引目标

建议：

不要贪多。

第一批：

内分泌方向

因为你自己最熟。

推荐：

1. 协和内科学（内分泌章节）


2. Williams Textbook of Endocrinology


3. ADA Standards of Care




---

22. 数据标准最终目标

最终形成：

PDF

↓

MRDS

↓

医学知识节点

↓

医生个人知识库


---

设计结论

MedicalReader真正的护城河：

不是：

❌ Flutter界面

❌ PDF渲染

而是：

✅ MRDS标准
✅ 医学知识索引库
✅ HIS式搜索逻辑

如果这个标准建立起来，几年后最大的资产不是代码，而是：

> 一个开源医学知识索引生态。



下一步应该继续做：

《MedicalReader v0.1 搜索引擎详细设计文档》

因为你提出的“HIS检索逻辑”实际上需要单独设计：

分词

同义词扩展

拼音匹配

ICD匹配

权重排序

模糊搜索

离线高速索引


这部分会决定实际使用体验。