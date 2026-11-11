extends RefCounted
## 对话数据库 ——《霜原-7》。
##
## 节点字段：
##   lines    : 台词数组。每行可以有 speaker（角色名）或 skill（技能内心声音），
##              没有两者则为旁白。可选 passive = {"skill", "dc"} 被动检定，失败则不显示。
##              可选 requires / requires_not 条件，color 指定说话人颜色。
##   options  : 选项数组。字段 text / next / requires / requires_not / once /
##              check = {"skill", "dc", "red"} + pass / fail（检定成败跳转）。
##   goto     : 台词播完后直接跳到另一个节点（例如对话“枢纽”）。
##   效果字段 : set / unset / effects{health, morale} / add_item / remove_item /
##              thought / quest / name / end_demo（台词播完后生效）。
##   "END"    : 结束对话。

const NODES := {
	# ================================================================ 开场
	"intro": {
		"lines": [
			{"text": "……黑暗。一片均匀的、不需要填任何表格的黑暗。"},
			{"skill": "hunch", "text": "然后——有什么东西落在你脸上。很轻。一片，又一片。雪在给你盖章。"},
			{"skill": "craving", "text": "嘴里有煤灰和劣质烈酒的味道。昨晚是个好夜晚。也许是配给制以来最好的一个。"},
			{"skill": "logic", "text": "先回答表格的第一栏：姓名。"},
			{"text": "那一栏是空的。"},
		],
		"options": [
			{"text": "我是……我是谁？", "next": "intro_who"},
			{"text": "再睡五分钟。", "next": "intro_sleep"},
		],
	},
	"intro_sleep": {
		"lines": [
			{"skill": "volition", "text": "不行。现在是零下三十一度。在这里睡五分钟的人，春天才会被找到。"},
			{"skill": "craving", "text": "春天。听上去是个不错的归宿。"},
		],
		"options": [{"text": "……好吧。睁开眼睛。", "next": "intro_wake"}],
	},
	"intro_who": {
		"lines": [
			{"skill": "logic", "text": "身份是由档案构成的。档案就在外面——在这个镇子里，在雪底下。"},
			{"skill": "empathy", "text": "还有，别害怕。害怕说明你还有东西舍不得丢。"},
		],
		"options": [{"text": "睁开眼睛。", "next": "intro_wake"}],
	},
	"intro_wake": {
		"lines": [
			{"text": "你睁开眼。一座混凝土候车亭，背墙上是马赛克拼的太阳。外面是霜原-7：第七矿的矿镇，极夜的第四十天。"},
			{"text": "大街两边的楼没有屋顶。远处，热电厂的烟囱把蒸汽一团一团地推进粉灰色的天里。"},
			{"skill": "perception", "text": "街对面有一只烧着火的铁桶。桶边站着一个人。他在看你。他大概已经看了很久了。"},
		],
		"quest": "找回你的名字",
		"options": [{"text": "[起身]", "next": "END"}],
	},

	# ================================================================ 老司炉（NPC）
	"anchor_start": {
		"lines": [
			{"requires_not": "met_anchor", "text": "一个裹着棉袄的老人，把双手伸向桶里的火。他的指节里嵌着洗不掉的煤，像一份盖过章的履历。"},
			{"requires_not": "met_anchor", "speaker": "老司炉", "text": "哟。候车亭里的冻肉活过来了。"},
			{"requires_not": "met_anchor", "skill": "empathy", "text": "他的玩笑里有一丝真心的松了口气。这桶火是为你烧的。烧了一整夜。"},
			{"requires": "met_anchor", "speaker": "炉叔", "text": "又是你。还没想起来？"},
		],
		"set": "met_anchor",
		"goto": "anchor_hub",
	},
	"anchor_hub": {
		"options": [
			{"text": "“你是谁？”", "next": "anchor_who", "once": true},
			{"text": "“你认识我吗？”", "next": "anchor_know", "once": true},
			{"text": "（观察他的手）推断他的工种。", "check": {"skill": "logic", "dc": 10}, "pass": "anchor_logic_pass", "fail": "anchor_logic_fail"},
			{"text": "“你在担心什么人。”", "requires": "anchor_named", "check": {"skill": "empathy", "dc": 12, "red": true}, "pass": "anchor_emp_pass", "fail": "anchor_emp_fail"},
			{"text": "“那五栋楼在哪儿？”", "requires": "know_name", "next": "anchor_after", "once": true},
			{"text": "[离开] “回头见。”", "next": "END"},
		],
	},
	"anchor_who": {
		"lines": [
			{"speaker": "炉叔", "text": "大家都叫我炉叔。在热电厂烧了三十一年锅炉。现在他们用机器添煤了，我就来烧这只桶。总得有东西是人烧的。"},
			{"skill": "hunch", "text": "炉。一个把冷东西变热的东西。你现在很需要这个。"},
		],
		"set": "anchor_named",
		"goto": "anchor_hub",
	},
	"anchor_know": {
		"lines": [
			{"speaker": "炉叔", "text": "认识？不。可昨晚整条街都认识你了。你是坐最后一班履带车来的，夹着一卷图纸，站在候车亭的长椅上数楼。"},
		],
		"options": [{"text": "“数楼？”", "next": "anchor_shout"}],
	},
	"anchor_shout": {
		"lines": [
			{"speaker": "炉叔", "text": "冲着大街喊：“一百三十二！图上有一百三十二栋！这儿只有一百二十七栋！”喊了半个钟头。"},
			{"speaker": "炉叔", "text": "后来你钻进东边那个终端亭，打了一张卡，哭了一会儿，又出来，睡了。哦对，你还往亭子底下塞了个什么东西。我眼神不行了，没看清。"},
			{"skill": "logic", "text": "终端亭。一个具体的地点，一个具体的物件。这是线索，不是口号。"},
		],
		"set": "heard_phone",
		"quest": "检查十字街东边的终端亭",
		"goto": "anchor_hub",
	},
	"anchor_logic_pass": {
		"lines": [
			{"skill": "logic", "text": "煤嵌在指节的纹路里，不在掌心——他握的是炉钩，不是镐。左手背上一片烫伤，边缘很齐：那是炉门的形状。他不是矿工。他是司炉。"},
			{"speaker": "你", "text": "“你是烧锅炉的。不是下井的。”"},
			{"speaker": "炉叔", "text": "……三十一年。眼睛挺尖嘛，冻肉同志。你也是干这个的？查人的？"},
			{"skill": "logic", "text": "“查人的”。他觉得你有一个行当。一个靠清点和核对吃饭的行当。"},
		],
		"set": "clue_profession",
		"goto": "anchor_hub",
	},
	"anchor_logic_fail": {
		"lines": [
			{"skill": "logic", "text": "这双手……很黑。很……像手。"},
			{"speaker": "炉叔", "text": "你盯着我的手看啥？要烤火就过来烤，不收票。"},
		],
		"goto": "anchor_hub",
	},
	"anchor_emp_pass": {
		"lines": [
			{"skill": "empathy", "text": "他每隔一会儿就往北看一眼。不是在看烟囱。是在看烟囱后面——井架的方向。他在等一个班升井。"},
			{"speaker": "你", "text": "“你在等人上来。”"},
			{"speaker": "炉叔", "text": "……我儿子。第七井，夜班。三天前下去的。调度室说“通讯检修”。通讯检修了三天。"},
			{"speaker": "炉叔", "text": "昨晚你喊“少了五栋”，我差点拿炉钩敲你。我还以为你喊的是“少了五个”。"},
			{"skill": "empathy", "text": "你不知道自己在找什么。可他很清楚自己在怕什么。"},
		],
		"thought": "等升井的人",
		"effects": {"morale": 1},
		"goto": "anchor_hub",
	},
	"anchor_emp_fail": {
		"lines": [
			{"skill": "empathy", "text": "他……冷？他在烤火，所以他大概是冷。"},
			{"speaker": "炉叔", "text": "别用那种眼神看我，跟工会来慰问似的。"},
		],
		"effects": {"morale": -1},
		"goto": "anchor_hub",
	},
	"anchor_after": {
		"lines": [
			{"speaker": "炉叔", "text": "普查员？那就对上了。图上有、地上没有的楼，这镇上人人都知道，人人都不说。"},
			{"speaker": "炉叔", "text": "它们不在镇子里。在边界外面，往北，过了热电厂。瓦伦，是吧？我记住了。等你回来，这桶火还给你烧着。"},
		],
		"goto": "anchor_hub",
	},

	# ================================================================ 终端亭
	"phone_start": {
		"lines": [
			{"text": "一座红漆斑驳的电话亭，里面的电话被拆掉了，换成一台公用终端。屏幕发着绿光，光标一下一下地眨。"},
			{"requires_not": "heard_phone", "skill": "hunch", "text": "它在等你。它记得你昨晚打进去的每一个孔。但它不会主动开口——机器都很守纪律。"},
			{"requires": "heard_phone", "requires_not": "know_name", "skill": "logic", "text": "炉叔说，你往底下塞了什么东西。"},
		],
		"goto": "phone_hub",
	},
	"phone_hub": {
		"options": [
			{"text": "读屏幕上的字。", "next": "phone_receiver", "once": true},
			{"text": "检查终端亭底部。", "requires_not": ["heard_phone", "phone_nothing"], "next": "phone_nothing"},
			{"text": "检查终端亭底部。", "requires": "heard_phone", "requires_not": "know_name", "check": {"skill": "perception", "dc": 8}, "pass": "phone_found", "fail": "phone_fail"},
			{"text": "跪进雪里，把整条胳膊伸进去摸。", "requires": "phone_search_failed", "requires_not": "know_name", "next": "phone_grope"},
			{"text": "[离开]", "next": "END"},
		],
	},
	"phone_receiver": {
		"lines": [
			{"speaker": "终端", "color": "5fe0b0", "text": "上一次查询：界外原轮廓，共五处。结果：无此建筑。无此建筑。无此建筑。无此建筑。无此建筑。"},
			{"speaker": "终端", "color": "5fe0b0", "text": "上一次查询：查询人本人。结果：——"},
			{"skill": "hunch", "text": "光标在那道横线后面眨。它也不知道。或者它知道，但没有权限说。"},
			{"skill": "volition", "text": "别盯着看了。一台机器不认识你，不等于你不存在。"},
		],
		"effects": {"morale": -1},
		"goto": "phone_hub",
	},
	"phone_nothing": {
		"lines": [
			{"skill": "perception", "text": "只有冻硬的雪、烟头和一张作废的配给票。你得先知道自己在找什么。"},
		],
		"set": "phone_nothing",
		"goto": "phone_hub",
	},
	"phone_fail": {
		"lines": [
			{"skill": "perception", "text": "手指冻得没有知觉了。你只摸到冰，和……一个烟头。也许是你的。"},
		],
		"set": "phone_search_failed",
		"goto": "phone_hub",
	},
	"phone_grope": {
		"lines": [
			{"text": "你跪进雪里，把整条胳膊塞进铁皮底座下面。袖口灌满了雪。膝盖在抗议。"},
		],
		"effects": {"health": -1},
		"goto": "phone_found",
	},
	"phone_found": {
		"lines": [
			{"text": "在铁皮底座和冻土之间，你摸到一个硬邦邦的塑料夹子。是一本工作证，冻在了一块冰里。"},
			{"text": "封皮上烫着字：「国家建筑普查委员会」。里面的照片被霜糊住了。姓名一栏是钢笔写的，洇开了一半：「瓦伦·科——」。职务：普查员。任务编号：B001–B132。"},
			{"skill": "logic", "text": "“瓦伦”。这个名字在你嘴里刚刚好合适，像一颗换回原位的牙。"},
			{"requires": "clue_profession", "skill": "logic", "text": "再加上炉叔那句话——一个靠清点吃饭的人。你是来数楼的。"},
			{"skill": "logic", "text": "一百三十二个编号。一百二十七栋在镇子里。剩下的五栋，轮廓画在了边界外面。有人把你派来找它们。然后你把自己的证件藏了起来。"},
			{"skill": "empathy", "text": "不是藏给别人看的。是藏给你自己的。你昨晚不想再当这个人了。"},
		],
		"set": "know_name",
		"add_item": "冻住的工作证",
		"thought": "界外的五栋",
		"name": "瓦伦·科——",
		"quest": "（已完成）你有了半个名字",
		"goto": "phone_end",
	},
	"phone_end": {
		"lines": [
			{"text": "热电厂的汽笛响了，很长的一声。极夜里没有黎明，只有换班。你有了一个名字的前半截，和一份没数完的清单。"},
			{"text": "[ 演示结束 · 感谢游玩 ]  你可以继续在镇子里逛逛。沿大街一直往北，是热电厂和选矿厂。"},
		],
		"end_demo": true,
		"options": [{"text": "[结束]", "next": "END"}],
	},

	# ================================================================ 冰面
	"puddle_start": {
		"lines": [
			{"text": "路中间的一片冰。车辙在这里压出了水，水又冻上了。有一张脸正从冰底下往上看着你。"},
		],
		"goto": "puddle_hub",
	},
	"puddle_hub": {
		"options": [
			{"text": "看看那张脸。", "next": "puddle_face", "once": true},
			{"text": "对它说：“振作起来，同志。”", "check": {"skill": "volition", "dc": 10}, "pass": "puddle_vol_pass", "fail": "puddle_vol_fail"},
			{"text": "[离开]", "next": "END"},
		],
	},
	"puddle_face": {
		"lines": [
			{"text": "眉毛上结着霜。三天没刮的胡子。一顶歪了的护耳帽，一件大了一号的呢子大衣。领口别着一枚徽章，被人用指甲刮花了。"},
			{"skill": "empathy", "text": "这张脸很累。不是一夜没睡的那种累，是填了很多年表格的那种。"},
			{"skill": "craving", "text": "这张脸需要一杯酒。就一杯。为了暖和。"},
		],
		"goto": "puddle_hub",
	},
	"puddle_vol_pass": {
		"lines": [
			{"skill": "volition", "text": "你挺直了背。冰里的人也挺直了背。很好。至少你们这个两人小组意见一致。"},
		],
		"effects": {"morale": 1},
		"goto": "puddle_hub",
	},
	"puddle_vol_fail": {
		"lines": [
			{"skill": "volition", "text": "你张开嘴，冰里的人也张开嘴。你们谁都没说出话来。只有两团白气。"},
			{"skill": "craving", "text": "看吧。连他都知道，该去喝一杯了。"},
		],
		"goto": "puddle_hub",
	},

	# ================================================================ 配给箱
	"crates_start": {
		"lines": [
			{"text": "一堆军绿色的配给箱，箱盖上喷着一颗星和一行编号。封条早就被撕掉了。"},
			{"requires_not": "has_bottle", "passive": {"skill": "perception", "dc": 9}, "skill": "perception", "text": "箱缝里塞着一个瓶子。有人把它藏在这儿，而且藏得不怎么用心。"},
		],
		"goto": "crates_hub",
	},
	"crates_hub": {
		"options": [
			{"text": "在箱子之间翻找。", "requires_not": "has_bottle", "check": {"skill": "perception", "dc": 8}, "pass": "crates_bottle", "fail": "crates_nothing"},
			{"text": "拧开瓶盖，喝一口。", "requires": "has_bottle", "requires_not": "bottle_gone", "next": "crates_drink"},
			{"text": "把瓶子塞回箱缝里，留给下一个人。", "requires": "has_bottle", "requires_not": "bottle_gone", "next": "crates_throw"},
			{"text": "[离开]", "next": "END"},
		],
	},
	"crates_bottle": {
		"lines": [
			{"text": "一个半满的扁酒瓶。标签上印着：「北风牌 · 工业酒精勾兑 · 每人每月限购一瓶」。"},
			{"skill": "craving", "text": "哦。哦哦哦。是它。它一直在这里等你。就像一个老同志。"},
			{"skill": "volition", "text": "不像老同志。像债主。"},
		],
		"set": "has_bottle",
		"add_item": "北风牌烈酒",
		"goto": "crates_hub",
	},
	"crates_nothing": {
		"lines": [
			{"skill": "perception", "text": "木刺。冻硬的麻袋。半块压缩饼干。没别的了。"},
		],
		"goto": "crates_hub",
	},
	"crates_drink": {
		"lines": [
			{"text": "液体像一根烧红的铁丝滑进喉咙。"},
			{"skill": "craving", "text": "对！就是这样！零下三十一度变成了零下三十度！"},
			{"skill": "volition", "text": "……你会后悔的。不是现在，但一定会。"},
		],
		"set": "bottle_gone",
		"remove_item": "北风牌烈酒",
		"effects": {"morale": 2, "health": -1},
		"goto": "crates_hub",
	},
	"crates_throw": {
		"lines": [
			{"text": "你把瓶子推回原处，又往里塞了塞。这一次藏得比上一个人用心。"},
			{"skill": "craving", "text": "你……你把它送人了。"},
			{"skill": "volition", "text": "做得好。这是今天第一件由你自己决定的事。"},
		],
		"set": "bottle_gone",
		"remove_item": "北风牌烈酒",
		"thought": "留给下一个人的东西",
		"effects": {"morale": 1},
		"goto": "crates_hub",
	},

	# ================================================================ 广播喇叭
	"lamp_start": {
		"lines": [
			{"text": "一根广播杆，顶上两只灰色的喇叭，各朝一个方向。杆上还挂着一盏灯，是这条街上唯一亮着的那盏。"},
			{"requires_not": "lamp_talked", "skill": "hunch", "text": "喇叭有话要对你说。不是对全镇。是对你。"},
		],
		"options": [
			{"text": "听它说。", "requires_not": "lamp_talked", "next": "lamp_talk"},
			{"text": "[离开]", "next": "END"},
		],
	},
	"lamp_talk": {
		"lines": [
			{"speaker": "喇叭", "color": "e9c27a", "text": "注意。注意。这里是霜原之声。现在播送寻人启事：候车亭里的那位同志，请到你自己这里来认领。"},
			{"speaker": "喇叭", "color": "e9c27a", "text": "我播了整整一夜。播天气，播产量，播进行曲。没有人听。广播的意义不在于有人听，在于不能停。"},
		],
		"set": "lamp_talked",
		"options": [
			{"text": "“谢谢你。”", "next": "lamp_thanks"},
			{"text": "“你只是一只喇叭。”", "next": "lamp_cold"},
		],
	},
	"lamp_thanks": {
		"lines": [
			{"speaker": "喇叭", "color": "e9c27a", "text": "……下面播送一段音乐。"},
			{"skill": "hunch", "text": "什么也没响。但灯好像暖了一度。也许只是你的错觉。也许不是。"},
		],
		"effects": {"morale": 1},
	},
	"lamp_cold": {
		"lines": [
			{"skill": "logic", "text": "正确。它只是一只喇叭。纸盆、线圈和一份播音计划。"},
			{"skill": "hunch", "text": "那它为什么停了一拍？"},
		],
	},

	# ================================================================ 文化宫大门
	"hotel_start": {
		"lines": [
			{"text": "「矿工文化宫」。霓虹招牌上的“文”字坏了，只剩“化宫”两个字在雪里一闪一闪。六根柱子，两条红条幅，一扇包着铁皮的门。"},
			{"passive": {"skill": "logic", "dc": 8}, "skill": "logic", "text": "门上贴着告示：今晚放映取消。明晚放映取消。告示的纸已经黄了。"},
		],
		"options": [
			{"text": "敲门。", "next": "hotel_knock", "once": true},
			{"text": "[离开]", "next": "END"},
		],
	},
	"hotel_knock": {
		"lines": [
			{"text": "你敲了三下。门里传来毡靴的声音，走近，停住了。然后又走远了。"},
			{"skill": "empathy", "text": "门后的人认出了你的大衣，不是认出了你。这里的人不给穿这种大衣的人开门。"},
		],
		"effects": {"morale": -1},
	},

	# ================================================================ 候车亭长椅
	"bench_start": {
		"lines": [
			{"text": "你醒来的那张长椅。木条上还留着一个人形的、没积雪的印子。墙上的时刻表被霜盖住了，只看得清一行：「末班车：视情况」。"},
			{"skill": "craving", "text": "回来躺下吧。这里什么都不会发生。这正是它的好处。"},
			{"skill": "volition", "text": "这也正是它的坏处。"},
		],
	},

	# ================================================================ 建筑编号索引牌
	"board_start": {
		"lines": [
			{"text": "一块公告牌。红色的抬头下面钉着一张图：《建筑编号索引 | B001–B132》。灰色的小方块是楼，橙色的是还住着人的楼，蓝色的是公家的。"},
			{"text": "图的右下角有一行小字：「编号分配后不重排。当前 127 栋位于界内，5 个原轮廓在边界外。」"},
			{"passive": {"skill": "logic", "dc": 9}, "skill": "logic", "text": "“原轮廓”。不是“计划中的”，不是“已拆除的”。是原来就有、现在不在界内的。楼没有动。动的是边界。"},
			{"skill": "perception", "text": "十字街口的位置被人用红铅笔画了一个圈，旁边写着：“你在这里。”字迹有点眼熟。"},
		],
		"set": "has_map",
		"options": [
			{"text": "把图抄在手心里。（按 M 查看地图）", "next": "board_copy", "once": true},
			{"text": "[离开]", "next": "END"},
		],
	},
	"board_copy": {
		"lines": [
			{"text": "你没有纸。你有一支笔和一只冻僵的手。"},
			{"skill": "hunch", "text": "抄到一半你发现，你根本不用看图。你的手记得每一栋楼的位置。"},
		],
		"thought": "手记得的地图",
	},

	# ================================================================ 宣传牌
	"billboard_start": {
		"lines": [
			{"text": "红底的宣传牌，奶油色的大字：「计划就是法律」。下面一行小一点：「每一栋楼都有编号，每一个人都有位置」。"},
			{"skill": "logic", "text": "反过来说：没有编号的楼不存在。没有位置的人也不存在。"},
			{"skill": "empathy", "text": "写这句话的人大概是真心觉得这很温暖。"},
		],
	},

	# ================================================================ 纪念碑
	"monument_start": {
		"lines": [
			{"text": "大街正中的一座混凝土方尖碑。基座上的年份是 1957。碑顶的红星通着电，在雪里是唯一一个不肯褪色的东西。"},
			{"passive": {"skill": "perception", "dc": 8}, "skill": "perception", "text": "基座背面刻着第一批建设者的名单。一百三十二个名字。有五个被凿掉了。"},
			{"skill": "hunch", "text": "星星在看着北边。它一直在看着北边。"},
		],
	},

	# ================================================================ 步行掘进机
	"walker_start": {
		"lines": [
			{"text": "一台四条腿的机器，半埋在雪里，像一头跪下去就没再起来的牲口。舷板上的白字还认得出：「★ 猛犸-2」。"},
			{"skill": "logic", "text": "步行式斗轮掘进机。设计寿命二十年。它是自己走到这儿来的，然后有人下了一道让它停下的命令，再没有人下过让它起来的命令。"},
			{"passive": {"skill": "hunch", "dc": 10}, "skill": "hunch", "text": "它的斗轮臂指着北边。和纪念碑上的星星一个方向。和边界外面那五栋楼一个方向。"},
			{"skill": "empathy", "text": "驾驶舱的玻璃上，有人从里面用手指写了一个字。结了霜，看不清了。"},
		],
	},
}
