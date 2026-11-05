extends RefCounted
## 对话数据库。
##
## 节点字段：
##   lines    : 台词数组。每行可以有 speaker（角色名）或 skill（技能内心声音），
##              没有两者则为旁白。可选 passive = {"skill", "dc"} 被动检定，失败则不显示。
##              可选 requires / requires_not 条件。
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
			{"text": "……黑暗。一片温暖的、无边无际的、什么都不必做的黑暗。"},
			{"skill": "hunch", "text": "然后——有什么东西在敲。不是门。是雨。雨点敲在你的脸上，像一封又一封的催缴信。"},
			{"skill": "craving", "text": "嘴里有铁锈和廉价烈酒的味道。昨晚是个好夜晚。也许是最好的那个。也许是最后一个。"},
			{"skill": "logic", "text": "先回答一个简单点的问题：你是谁？"},
			{"text": "答案没有来。答案在别的什么地方。"},
		],
		"options": [
			{"text": "我是……我是谁？", "next": "intro_who"},
			{"text": "再睡五分钟。", "next": "intro_sleep"},
		],
	},
	"intro_sleep": {
		"lines": [
			{"skill": "volition", "text": "不行。你正躺在一张湿透的长椅上。再睡下去，你就会变成长椅的一部分。"},
			{"skill": "craving", "text": "长椅不会宿醉。长椅很幸福。"},
		],
		"options": [{"text": "……好吧。睁开眼睛。", "next": "intro_wake"}],
	},
	"intro_who": {
		"lines": [
			{"skill": "logic", "text": "身份是由证据构成的。而证据就在外面——在港口，在雨里。"},
			{"skill": "empathy", "text": "还有，别害怕。害怕也是一种记得自己的方式。"},
		],
		"options": [{"text": "睁开眼睛。", "next": "intro_wake"}],
	},
	"intro_wake": {
		"lines": [
			{"text": "你睁开眼。黎明前的维斯珀港。灰蓝色的天光，一盏还亮着的路灯，远处有火光在铁桶里跳动。"},
			{"skill": "perception", "text": "铁桶旁边站着一个人。他在看你。他大概已经看了很久了。"},
		],
		"quest": "找回你的名字",
		"options": [{"text": "[起身]", "next": "END"}],
	},

	# ================================================================ 锚叔（NPC）
	"anchor_start": {
		"lines": [
			{"requires_not": "met_anchor", "text": "一个穿橘色防水服的老人，把双手伸向桶里的火。他的指节像缆绳上的结。"},
			{"requires_not": "met_anchor", "speaker": "老码头工", "text": "哟。长椅上的尸体活过来了。"},
			{"requires_not": "met_anchor", "skill": "empathy", "text": "他的玩笑里有一丝真心的松了口气。他守着你守了一整夜。"},
			{"requires": "met_anchor", "speaker": "锚叔", "text": "又是你。还没想起来？"},
		],
		"set": "met_anchor",
		"goto": "anchor_hub",
	},
	"anchor_hub": {
		"options": [
			{"text": "“你是谁？”", "next": "anchor_who", "once": true},
			{"text": "“你认识我吗？”", "next": "anchor_know", "once": true},
			{"text": "（观察他的手）推断他的职业。", "check": {"skill": "logic", "dc": 10}, "pass": "anchor_logic_pass", "fail": "anchor_logic_fail"},
			{"text": "“你在担心什么人。”", "requires": "anchor_named", "check": {"skill": "empathy", "dc": 12, "red": true}, "pass": "anchor_emp_pass", "fail": "anchor_emp_fail"},
			{"text": "“我找到了电话亭底下的东西。”", "requires": "know_name", "next": "anchor_after", "once": true},
			{"text": "[离开] “回头见。”", "next": "END"},
		],
	},
	"anchor_who": {
		"lines": [
			{"speaker": "锚叔", "text": "大家都叫我锚叔。在这个码头卸了三十一年货。现在没货可卸了，我就把自己卸在这只桶旁边。"},
			{"skill": "hunch", "text": "锚。一个把东西固定住的东西。你现在很需要这个。"},
		],
		"set": "anchor_named",
		"goto": "anchor_hub",
	},
	"anchor_know": {
		"lines": [
			{"speaker": "锚叔", "text": "认识？不。但昨晚整个港区都认识你了。你站在那张长椅上，冲着大海喊了半个钟头。"},
		],
		"options": [{"text": "“我喊了什么？”", "next": "anchor_shout"}],
	},
	"anchor_shout": {
		"lines": [
			{"speaker": "锚叔", "text": "喊“灯塔”。喊“她不会回来了”。然后你钻进那个电话亭打了个电话，哭了一会儿，又出来，睡了。"},
			{"speaker": "锚叔", "text": "哦对，你还往电话亭底下塞了个什么东西。我老了，眼神不好，没看清是啥。"},
			{"skill": "logic", "text": "电话亭。一个具体的地点，一个具体的物件。这是线索，不是诗。"},
		],
		"set": "heard_phone",
		"quest": "检查港口西侧的电话亭",
		"goto": "anchor_hub",
	},
	"anchor_logic_pass": {
		"lines": [
			{"skill": "logic", "text": "老茧在虎口而不在掌心——他不只是搬运工，他开过起重机。右手小指断过，没接正：那是缆绳回弹留下的。他是码头上的老手，见过的事情比他说出口的多。"},
			{"speaker": "你", "text": "“你开过吊车。”"},
			{"speaker": "锚叔", "text": "……开了二十年。眼睛挺尖嘛，长椅先生。干这行的？"},
			{"skill": "logic", "text": "“这行”。他认为你有一个行当。一个靠观察别人的手吃饭的行当。"},
		],
		"set": "clue_profession",
		"goto": "anchor_hub",
	},
	"anchor_logic_fail": {
		"lines": [
			{"skill": "logic", "text": "这双手……很大。很……像手。"},
			{"speaker": "锚叔", "text": "你盯着我的手看啥？要烤火就过来烤。"},
		],
		"goto": "anchor_hub",
	},
	"anchor_emp_pass": {
		"lines": [
			{"skill": "empathy", "text": "他每隔几秒就看一眼海面。不是在看天气。是在等一条船。一条早就该回来的船。"},
			{"speaker": "你", "text": "“你在等人回来。”"},
			{"speaker": "锚叔", "text": "……我儿子。“海鸥号”。三天前出的港，说好昨天回来。"},
			{"speaker": "锚叔", "text": "昨晚你喊“她不会回来了”，我差点把你扔进海里。还以为你说的是那条船。"},
			{"skill": "empathy", "text": "你不知道自己在为谁哭。但他很清楚自己在为谁害怕。"},
		],
		"thought": "等船的人",
		"effects": {"morale": 1},
		"goto": "anchor_hub",
	},
	"anchor_emp_fail": {
		"lines": [
			{"skill": "empathy", "text": "他……冷？他在烤火，所以他大概是冷。"},
			{"speaker": "锚叔", "text": "别用那种眼神看我，跟个神父似的。"},
		],
		"effects": {"morale": -1},
		"goto": "anchor_hub",
	},
	"anchor_after": {
		"lines": [
			{"speaker": "锚叔", "text": "找到了？那就好。名字是个好东西。丢了名字就跟丢了船锚一样——你会一直漂。"},
			{"speaker": "锚叔", "text": "瓦伦，是吧？我会记住的。我的记性比眼神好。"},
		],
		"goto": "anchor_hub",
	},

	# ================================================================ 电话亭
	"phone_start": {
		"lines": [
			{"text": "一座红漆斑驳的电话亭。玻璃上全是雾气，听筒垂在一边，像一只耷拉下来的手。"},
			{"requires_not": "heard_phone", "skill": "hunch", "text": "它在等你。它知道你昨晚说了些什么。但它不会主动开口——电话亭都很有礼貌。"},
			{"requires": "heard_phone", "requires_not": "know_name", "skill": "logic", "text": "锚叔说，你往底下塞了什么东西。"},
		],
		"goto": "phone_hub",
	},
	"phone_hub": {
		"options": [
			{"text": "拿起听筒。", "next": "phone_receiver", "once": true},
			{"text": "检查电话亭底部。", "requires_not": ["heard_phone", "phone_nothing"], "next": "phone_nothing"},
			{"text": "检查电话亭底部。", "requires": "heard_phone", "requires_not": "know_name", "check": {"skill": "perception", "dc": 8}, "pass": "phone_found", "fail": "phone_fail"},
			{"text": "跪进积水里，把整条胳膊伸进去摸。", "requires": "phone_search_failed", "requires_not": "know_name", "next": "phone_grope"},
			{"text": "[离开]", "next": "END"},
		],
	},
	"phone_receiver": {
		"lines": [
			{"text": "听筒冰凉。里面只有忙音：嘟——嘟——嘟——"},
			{"skill": "hunch", "text": "在忙音的间隙里，你听见一个女人的声音：“……别再打来了。”——不。那是记忆，不是线路。"},
			{"skill": "volition", "text": "放下它。现在还不是时候。"},
		],
		"effects": {"morale": -1},
		"goto": "phone_hub",
	},
	"phone_nothing": {
		"lines": [
			{"skill": "perception", "text": "只有泥水、烟头和一张泡烂的电车票。你得先知道自己在找什么。"},
		],
		"set": "phone_nothing",
		"goto": "phone_hub",
	},
	"phone_fail": {
		"lines": [
			{"skill": "perception", "text": "太暗了。你的手指只摸到冰冷的泥浆，和……一个烟头。也许是你的。"},
		],
		"set": "phone_search_failed",
		"goto": "phone_hub",
	},
	"phone_grope": {
		"lines": [
			{"text": "你跪进积水里，把整条胳膊塞进铁皮底座下面。膝盖在抗议。"},
		],
		"effects": {"health": -1},
		"goto": "phone_found",
	},
	"phone_found": {
		"lines": [
			{"text": "在电话亭的铁皮底座和石板之间，你摸到一个泡得发软的火柴盒。"},
			{"text": "封面印着：「灯塔酒吧 · 通宵营业」。背面是钢笔字，被雨水晕开了一半：「瓦伦·科——」，后面跟着一串电话号码。"},
			{"skill": "logic", "text": "“瓦伦”。这个名字在你嘴里刚刚好合适，像一颗换回原位的牙。"},
			{"requires": "clue_profession", "skill": "logic", "text": "再加上锚叔那句话——一个靠观察别人吃饭的人。警察。你是个警察。"},
			{"skill": "empathy", "text": "号码不是你的。是她的。是你昨晚打过去的那个号码。"},
		],
		"set": "know_name",
		"add_item": "湿火柴盒",
		"thought": "瓦伦·科——",
		"name": "瓦伦·科——",
		"quest": "（已完成）你有了半个名字",
		"goto": "phone_end",
	},
	"phone_end": {
		"lines": [
			{"text": "黎明终于从仓库的屋顶后面爬了出来。你有了一个名字的前半截。剩下的半截，和其他的一切，都还在雨里。"},
			{"text": "[ 演示结束 · 感谢游玩 ]  你可以继续在港区里逛逛。"},
		],
		"end_demo": true,
		"options": [{"text": "[结束]", "next": "END"}],
	},

	# ================================================================ 积水
	"puddle_start": {
		"lines": [
			{"text": "一洼积水。路灯的光在里面碎成了好几块。有一张脸正从水底往上看着你。"},
		],
		"goto": "puddle_hub",
	},
	"puddle_hub": {
		"options": [
			{"text": "看看那张脸。", "next": "puddle_face", "once": true},
			{"text": "对它说：“振作起来。”", "check": {"skill": "volition", "dc": 10}, "pass": "puddle_vol_pass", "fail": "puddle_vol_fail"},
			{"text": "[离开]", "next": "END"},
		],
	},
	"puddle_face": {
		"lines": [
			{"text": "浮肿的眼睛。三天没刮的胡子。一件大了一号的风衣。领口有一块深色污渍——可能是酒，也可能是别的。"},
			{"skill": "empathy", "text": "这张脸很累。不是一夜没睡的那种累，是很多年的那种。"},
			{"skill": "craving", "text": "这张脸需要一杯酒。就一杯。为了暖和。"},
		],
		"goto": "puddle_hub",
	},
	"puddle_vol_pass": {
		"lines": [
			{"skill": "volition", "text": "你挺直了背。水里的人也挺直了背。很好。至少你们俩意见一致。"},
		],
		"effects": {"morale": 1},
		"goto": "puddle_hub",
	},
	"puddle_vol_fail": {
		"lines": [
			{"skill": "volition", "text": "你张开嘴，水里的人也张开嘴。你们谁都没说出话来。"},
			{"skill": "craving", "text": "看吧。连他都知道，该去喝一杯了。"},
		],
		"goto": "puddle_hub",
	},

	# ================================================================ 木箱
	"crates_start": {
		"lines": [
			{"text": "一堆被雨泡胀了的木箱，上面印着褪色的货运编号。"},
			{"requires_not": "has_bottle", "passive": {"skill": "perception", "dc": 9}, "skill": "perception", "text": "箱缝里塞着一个瓶子。有人把它藏在这儿，而且藏得不怎么用心。"},
		],
		"goto": "crates_hub",
	},
	"crates_hub": {
		"options": [
			{"text": "在箱子之间翻找。", "requires_not": "has_bottle", "check": {"skill": "perception", "dc": 8}, "pass": "crates_bottle", "fail": "crates_nothing"},
			{"text": "拧开瓶盖，喝一口。", "requires": "has_bottle", "requires_not": "bottle_gone", "next": "crates_drink"},
			{"text": "把瓶子扔进海里。", "requires": "has_bottle", "requires_not": "bottle_gone", "next": "crates_throw"},
			{"text": "[离开]", "next": "END"},
		],
	},
	"crates_bottle": {
		"lines": [
			{"text": "一个半满的扁酒瓶。标签上写着：「北风牌 · 谷物烈酒」。"},
			{"skill": "craving", "text": "哦。哦哦哦。是它。它一直在这里等你。就像一个老朋友。"},
			{"skill": "volition", "text": "不像老朋友。像债主。"},
		],
		"set": "has_bottle",
		"add_item": "北风牌烈酒",
		"goto": "crates_hub",
	},
	"crates_nothing": {
		"lines": [
			{"skill": "perception", "text": "木刺。潮湿的木头。一只受了惊的螃蟹。没别的了。"},
		],
		"goto": "crates_hub",
	},
	"crates_drink": {
		"lines": [
			{"text": "液体像一根烧红的铁丝滑进喉咙。"},
			{"skill": "craving", "text": "对！就是这样！世界重新变得柔软了！"},
			{"skill": "volition", "text": "……你会后悔的。不是现在，但一定会。"},
		],
		"set": "bottle_gone",
		"remove_item": "北风牌烈酒",
		"effects": {"morale": 2, "health": -1},
		"goto": "crates_hub",
	},
	"crates_throw": {
		"lines": [
			{"text": "瓶子划出一道弧线，扑通一声。海面合上了，像什么都没发生过。"},
			{"skill": "craving", "text": "你……你杀了它。"},
			{"skill": "volition", "text": "做得好。这是今天第一件由你自己决定的事。"},
		],
		"set": "bottle_gone",
		"remove_item": "北风牌烈酒",
		"thought": "扔进海里的东西",
		"effects": {"morale": 1},
		"goto": "crates_hub",
	},

	# ================================================================ 路灯
	"lamp_start": {
		"lines": [
			{"text": "一盏铸铁路灯，是这条街上唯一还亮着的那盏。灯罩底部积了一层死去的飞蛾。"},
			{"requires_not": "lamp_talked", "skill": "hunch", "text": "路灯有话要对你说。"},
		],
		"options": [
			{"text": "听它说。", "requires_not": "lamp_talked", "next": "lamp_talk"},
			{"text": "[离开]", "next": "END"},
		],
	},
	"lamp_talk": {
		"lines": [
			{"speaker": "路灯", "color": "e9c27a", "text": "我亮了整整一夜。为了你。你躺在那张长椅上，像一件被人遗忘的外套。"},
			{"speaker": "路灯", "color": "e9c27a", "text": "天一亮他们就会把我关掉。没有人会说谢谢。从来没有人对一盏灯说谢谢。"},
		],
		"set": "lamp_talked",
		"options": [
			{"text": "“谢谢你。”", "next": "lamp_thanks"},
			{"text": "“你只是一盏灯。”", "next": "lamp_cold"},
		],
	},
	"lamp_thanks": {
		"lines": [
			{"speaker": "路灯", "color": "e9c27a", "text": "……"},
			{"skill": "hunch", "text": "灯光好像暖了一度。也许只是你的错觉。也许不是。"},
		],
		"effects": {"morale": 1},
	},
	"lamp_cold": {
		"lines": [
			{"skill": "logic", "text": "正确。它只是一盏灯。钨丝、玻璃和市政预算。"},
			{"skill": "hunch", "text": "那它为什么在发抖？"},
		],
	},

	# ================================================================ 旅馆大门
	"hotel_start": {
		"lines": [
			{"text": "「维斯珀旅馆」。霓虹招牌上的“旅”字坏了，只剩下“维斯珀 馆”几个字在雨里一闪一闪。"},
			{"passive": {"skill": "logic", "dc": 8}, "skill": "logic", "text": "门上贴着告示：本店不接待醉汉、水手和警察。这三样里你至少占了一样。"},
		],
		"options": [
			{"text": "敲门。", "next": "hotel_knock", "once": true},
			{"text": "[离开]", "next": "END"},
		],
	},
	"hotel_knock": {
		"lines": [
			{"text": "你敲了三下。门里传来拖鞋的声音，走近，停住了。然后又走远了。"},
			{"skill": "empathy", "text": "门后的人认出了你，但不想开门。你昨晚可能来过这里。"},
		],
		"effects": {"morale": -1},
	},

	# ================================================================ 长椅
	"bench_start": {
		"lines": [
			{"text": "你醒来的那张长椅。木条上还留着你的体温，和一块形状可疑的水渍。"},
			{"skill": "craving", "text": "回来躺下吧。这里什么都不会发生。这正是它的好处。"},
			{"skill": "volition", "text": "这也正是它的坏处。"},
		],
	},
}
