/// 검색해서 고르는 음식(메뉴) 카탈로그 — 100가지 이상.
///
/// 각 메뉴는 규칙 판정에 쓰이는 [category](= [FoodTag] id)로 묶여 있어,
/// 사용자가 구체적인 메뉴(예: "라면")를 골라도 단계별 식단 규칙(예: 밀가루·면·빵
/// 제한)이 그대로 적용됩니다. 저장은 `food_tags text[]` 컬럼을 그대로 쓰며,
/// 먹은 양(인분/개수)이 1이 아니면 `"<id>@<양>"` 형태로 인코딩합니다.
library;

import 'diet_rules.dart';

/// 검색·선택 가능한 개별 메뉴.
class FoodItem {
  const FoodItem(this.id, this.label, this.category);

  final String id;
  final String label;

  /// 규칙 판정용 분류 = [FoodTags] 의 id (protein, refined_carbs, ...).
  final String category;

  /// 분류 한글 라벨(예: "밀가루·면·빵"). 없으면 빈 문자열.
  String get categoryLabel => FoodTags.byId(category)?.label ?? '';
}

/// 먹은 메뉴 + 양(인분/개수). 저장/복원용 인코딩을 함께 제공.
class FoodPortion {
  const FoodPortion(this.id, [this.amount = 1]);

  /// 메뉴 id(신규) 또는 레거시 분류 id.
  final String id;

  /// 먹은 양(인분/개수). 기본 1.
  final double amount;

  String get label => FoodCatalog.labelOf(id);

  /// 규칙 판정용 분류 id(없으면 null).
  String? get category => FoodCatalog.categoryOf(id);

  /// 양 표시용 문자열("1", "1.5", "0.5").
  String get amountText {
    if (amount == amount.roundToDouble()) return amount.toInt().toString();
    return amount.toString();
  }

  /// 칩·목록 표시용("닭가슴살", "라면 ×1.5").
  String get display => amount == 1 ? label : '$label ×$amountText';

  /// 저장용 문자열. 양이 1이면 id 그대로(레거시 호환), 아니면 "id@양".
  String encode() => amount == 1 ? id : '$id@$amountText';

  FoodPortion copyWith({double? amount}) =>
      FoodPortion(id, amount ?? this.amount);

  /// 저장 문자열 → FoodPortion. "@" 뒤가 양, 없으면 1.
  static FoodPortion decode(String raw) {
    final at = raw.indexOf('@');
    if (at < 0) return FoodPortion(raw);
    final id = raw.substring(0, at);
    final amt = double.tryParse(raw.substring(at + 1)) ?? 1;
    return FoodPortion(id, amt <= 0 ? 1 : amt);
  }
}

/// 100가지 이상의 메뉴 풀 + 검색/조회 헬퍼.
class FoodCatalog {
  FoodCatalog._();

  static const all = <FoodItem>[
    // --- 단백질(고기·생선) ---
    FoodItem('chicken_breast', '닭가슴살', 'protein'),
    FoodItem('chicken_thigh', '닭다리살', 'protein'),
    FoodItem('grilled_chicken', '닭구이', 'protein'),
    FoodItem('samgyetang', '삼계탕', 'protein'),
    FoodItem('beef_bulgogi', '소불고기', 'protein'),
    FoodItem('beef_steak', '소고기 스테이크', 'protein'),
    FoodItem('chadolbagi', '차돌박이', 'protein'),
    FoodItem('galbi', '갈비', 'protein'),
    FoodItem('pork_belly', '삼겹살', 'protein'),
    FoodItem('pork_neck', '목살', 'protein'),
    FoodItem('pork_loin', '돼지등심', 'protein'),
    FoodItem('bossam', '보쌈', 'protein'),
    FoodItem('jeyuk', '제육볶음', 'protein'),
    FoodItem('duck_meat', '오리고기', 'protein'),
    FoodItem('lamb', '양고기', 'protein'),
    FoodItem('salmon', '연어', 'protein'),
    FoodItem('grilled_mackerel', '고등어구이', 'protein'),
    FoodItem('hairtail', '갈치구이', 'protein'),
    FoodItem('tuna_sashimi', '참치회', 'protein'),
    FoodItem('sashimi', '모둠회', 'protein'),
    FoodItem('shrimp', '새우', 'protein'),
    FoodItem('squid', '오징어', 'protein'),
    FoodItem('octopus', '문어', 'protein'),
    FoodItem('clam', '조개', 'protein'),
    FoodItem('mussel', '홍합', 'protein'),
    FoodItem('crab', '게', 'protein'),
    FoodItem('pollock', '동태·명태', 'protein'),
    FoodItem('eel', '장어', 'protein'),
    FoodItem('cod', '대구', 'protein'),

    // --- 채소 ---
    FoodItem('lettuce', '상추', 'vegetable'),
    FoodItem('spinach', '시금치', 'vegetable'),
    FoodItem('broccoli', '브로콜리', 'vegetable'),
    FoodItem('cabbage', '양배추', 'vegetable'),
    FoodItem('kimchi', '김치', 'vegetable'),
    FoodItem('cucumber', '오이', 'vegetable'),
    FoodItem('tomato', '토마토', 'vegetable'),
    FoodItem('cherry_tomato', '방울토마토', 'vegetable'),
    FoodItem('paprika', '파프리카', 'vegetable'),
    FoodItem('carrot', '당근', 'vegetable'),
    FoodItem('onion', '양파', 'vegetable'),
    FoodItem('zucchini', '애호박', 'vegetable'),
    FoodItem('eggplant', '가지', 'vegetable'),
    FoodItem('perilla_leaf', '깻잎', 'vegetable'),
    FoodItem('bean_sprout', '콩나물', 'vegetable'),
    FoodItem('radish', '무', 'vegetable'),
    FoodItem('salad', '샐러드', 'vegetable'),
    FoodItem('namul', '나물무침', 'vegetable'),
    FoodItem('kale', '케일', 'vegetable'),
    FoodItem('pepper', '고추', 'vegetable'),
    FoodItem('green_onion', '파', 'vegetable'),

    // --- 셰이크 ---
    FoodItem('protein_shake', '단백질 셰이크', 'shake'),
    FoodItem('switchon_shake', '스위치온 셰이크', 'shake'),

    // --- 계란 ---
    FoodItem('boiled_egg', '삶은 계란', 'egg'),
    FoodItem('fried_egg', '계란후라이', 'egg'),
    FoodItem('steamed_egg', '계란찜', 'egg'),
    FoodItem('scrambled_egg', '스크램블에그', 'egg'),
    FoodItem('rolled_omelette', '계란말이', 'egg'),

    // --- 두부 ---
    FoodItem('tofu_plain', '두부', 'tofu'),
    FoodItem('soft_tofu', '순두부', 'tofu'),
    FoodItem('grilled_tofu', '두부구이', 'tofu'),
    FoodItem('sundubu_jjigae', '순두부찌개', 'tofu'),

    // --- 요거트 ---
    FoodItem('greek_yogurt', '그릭요거트', 'yogurt'),
    FoodItem('plain_yogurt', '무가당 요거트', 'yogurt'),

    // --- 해조류 ---
    FoodItem('gim', '김', 'seaweed'),
    FoodItem('miyeok', '미역', 'seaweed'),
    FoodItem('miyeok_guk', '미역국', 'seaweed'),
    FoodItem('kelp', '다시마', 'seaweed'),
    FoodItem('tot', '톳', 'seaweed'),

    // --- 버섯 ---
    FoodItem('king_oyster_mushroom', '새송이버섯', 'mushroom'),
    FoodItem('shiitake', '표고버섯', 'mushroom'),
    FoodItem('enoki', '팽이버섯', 'mushroom'),
    FoodItem('button_mushroom', '양송이버섯', 'mushroom'),

    // --- 아보카도 ---
    FoodItem('avocado', '아보카도', 'avocado'),

    // --- 견과류 ---
    FoodItem('almond', '아몬드', 'nuts'),
    FoodItem('walnut', '호두', 'nuts'),
    FoodItem('cashew', '캐슈넛', 'nuts'),
    FoodItem('peanut', '땅콩', 'nuts'),
    FoodItem('mixed_nuts', '믹스넛', 'nuts'),

    // --- 치즈·우유 ---
    FoodItem('cheese_slice', '치즈', 'cheese'),
    FoodItem('milk', '우유', 'cheese'),
    FoodItem('string_cheese', '스트링치즈', 'cheese'),
    FoodItem('cottage_cheese', '코티지치즈', 'cheese'),

    // --- 블랙커피 ---
    FoodItem('black_coffee_cup', '블랙커피', 'black_coffee'),
    FoodItem('americano', '아메리카노', 'black_coffee'),

    // --- 밥·곡물 ---
    FoodItem('white_rice', '흰쌀밥', 'rice'),
    FoodItem('multigrain_rice', '잡곡밥', 'rice'),
    FoodItem('brown_rice', '현미밥', 'rice'),
    FoodItem('barley_rice', '보리밥', 'rice'),
    FoodItem('gimbap', '김밥', 'rice'),
    FoodItem('bibimbap', '비빔밥', 'rice'),
    FoodItem('fried_rice', '볶음밥', 'rice'),
    FoodItem('rice_porridge', '죽', 'rice'),
    FoodItem('sweet_potato', '고구마', 'rice'),
    FoodItem('potato', '감자', 'rice'),
    FoodItem('corn', '옥수수', 'rice'),
    FoodItem('oatmeal', '오트밀', 'rice'),

    // --- 밀가루·면·빵 ---
    FoodItem('ramen', '라면', 'refined_carbs'),
    FoodItem('jjajangmyeon', '짜장면', 'refined_carbs'),
    FoodItem('udon', '우동', 'refined_carbs'),
    FoodItem('pasta', '파스타', 'refined_carbs'),
    FoodItem('kalguksu', '칼국수', 'refined_carbs'),
    FoodItem('naengmyeon', '냉면', 'refined_carbs'),
    FoodItem('bread', '빵', 'refined_carbs'),
    FoodItem('toast', '토스트', 'refined_carbs'),
    FoodItem('bagel', '베이글', 'refined_carbs'),
    FoodItem('sandwich', '샌드위치', 'refined_carbs'),
    FoodItem('burger', '햄버거', 'refined_carbs'),
    FoodItem('pizza', '피자', 'refined_carbs'),
    FoodItem('tteokbokki', '떡볶이', 'refined_carbs'),
    FoodItem('dumpling', '만두', 'refined_carbs'),
    FoodItem('sujebi', '수제비', 'refined_carbs'),
    FoodItem('rice_cake', '떡', 'refined_carbs'),

    // --- 당류·디저트 ---
    FoodItem('cake', '케이크', 'sugar'),
    FoodItem('chocolate', '초콜릿', 'sugar'),
    FoodItem('candy', '사탕', 'sugar'),
    FoodItem('ice_cream', '아이스크림', 'sugar'),
    FoodItem('cookie', '쿠키', 'sugar'),
    FoodItem('donut', '도넛', 'sugar'),
    FoodItem('macaron', '마카롱', 'sugar'),
    FoodItem('soda', '탄산음료', 'sugar'),
    FoodItem('juice', '주스', 'sugar'),
    FoodItem('bubble_tea', '버블티', 'sugar'),
    FoodItem('sweet_latte', '가당 라떼', 'sugar'),
    FoodItem('honey', '꿀', 'sugar'),

    // --- 과일 ---
    FoodItem('apple', '사과', 'fruit'),
    FoodItem('banana', '바나나', 'fruit'),
    FoodItem('strawberry', '딸기', 'fruit'),
    FoodItem('grape', '포도', 'fruit'),
    FoodItem('orange', '오렌지', 'fruit'),
    FoodItem('watermelon', '수박', 'fruit'),
    FoodItem('blueberry', '블루베리', 'fruit'),
    FoodItem('kiwi', '키위', 'fruit'),
    FoodItem('mango', '망고', 'fruit'),
    FoodItem('pear', '배', 'fruit'),
    FoodItem('peach', '복숭아', 'fruit'),
    FoodItem('tangerine', '귤', 'fruit'),
    FoodItem('pineapple', '파인애플', 'fruit'),

    // --- 가공식품 ---
    FoodItem('ham', '햄', 'processed'),
    FoodItem('sausage', '소시지', 'processed'),
    FoodItem('bacon', '베이컨', 'processed'),
    FoodItem('spam', '스팸', 'processed'),
    FoodItem('fish_cake', '어묵', 'processed'),
    FoodItem('canned_tuna', '참치캔', 'processed'),
    FoodItem('cup_ramen', '컵라면', 'processed'),

    // --- 튀김 ---
    FoodItem('fried_chicken', '치킨(튀김)', 'fried'),
    FoodItem('tempura', '튀김', 'fried'),
    FoodItem('donkatsu', '돈까스', 'fried'),
    FoodItem('french_fries', '감자튀김', 'fried'),
    FoodItem('corn_dog', '핫도그', 'fried'),
    FoodItem('chicken_nugget', '치킨너겟', 'fried'),

    // --- 술 ---
    FoodItem('beer', '맥주', 'alcohol'),
    FoodItem('soju', '소주', 'alcohol'),
    FoodItem('wine', '와인', 'alcohol'),
    FoodItem('makgeolli', '막걸리', 'alcohol'),
    FoodItem('whiskey', '위스키', 'alcohol'),
    FoodItem('highball', '하이볼', 'alcohol'),
    FoodItem('cocktail', '칵테일', 'alcohol'),
  ];

  static final Map<String, FoodItem> _byId = {
    for (final f in all) f.id: f,
  };

  static FoodItem? byId(String id) => _byId[id];

  /// 저장된 id(메뉴 id 또는 레거시 분류 id) → 표시 라벨.
  static String labelOf(String id) =>
      _byId[id]?.label ?? FoodTags.byId(id)?.label ?? id;

  /// 저장된 id → 규칙 판정용 분류 id. 알 수 없으면 null.
  static String? categoryOf(String id) {
    final item = _byId[id];
    if (item != null) return item.category;
    // 레거시: 저장된 값이 분류 id 그 자체인 경우.
    if (FoodTags.byId(id) != null) return id;
    return null;
  }

  /// 라벨·분류 라벨로 검색. 빈 검색어는 전체를 그대로 반환.
  static List<FoodItem> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return all;
    return all
        .where((f) => f.label.contains(q) || f.categoryLabel.contains(q))
        .toList();
  }
}
