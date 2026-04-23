type InsightCategory =
  | "housing"
  | "affordability"
  | "mobility"
  | "demographics"
  | "governance"
  | "geography";

type InsightSeverity = "neutral" | "positive" | "caution";

type Demographics = {
  averageHouseholdSize?: number | null;
  medianGrossRent?: number | null;
  medianHomeValue?: number | null;
  ownerOccupiedPct?: number | null;
  povertyRatePct?: number | null;
  renterOccupiedPct?: number | null;
  workersWfhPct?: number | null;
};

export type InsightResponse = {
  category: InsightCategory;
  severity: InsightSeverity;
  title: string;
  detail: string;
};

type InsightStrings = {
  averageHouseholdSizeTitle: string;
  highQualifier: string;
  higherPovertyRateTitle: string;
  housingSnapshotTitle: string;
  homeownershipFormat: string;
  lowerPovertyRateTitle: string;
  medianGrossRentFormat: string;
  medianGrossRentHighFormat: string;
  medianHomeValueFormat: string;
  medianHomeValueHighFormat: string;
  ownerOccupiedFormat: string;
  peoplePerHouseholdFormat: string;
  povertyRateDetailFormat: string;
  povertyRateTitle: string;
  remoteWorkCommonTitle: string;
  remoteWorkDetailFormat: string;
  remoteWorkLessCommonTitle: string;
};

const en: InsightStrings = {
  averageHouseholdSizeTitle: "Average household size",
  highQualifier: "(high)",
  higherPovertyRateTitle: "Higher poverty rate",
  housingSnapshotTitle: "Housing snapshot",
  homeownershipFormat: "Homeownership at %@ with average household size of %@",
  lowerPovertyRateTitle: "Lower poverty rate",
  medianGrossRentFormat: "Median gross rent: %@",
  medianGrossRentHighFormat: "Median gross rent: %@ %@",
  medianHomeValueFormat: "Median home value: %@",
  medianHomeValueHighFormat: "Median home value: %@ %@",
  ownerOccupiedFormat: "%@ owner-occupied, %@ renter-occupied",
  peoplePerHouseholdFormat: "%@ people per household.",
  povertyRateDetailFormat: "%@ of people are below the poverty line (ACS estimate).",
  povertyRateTitle: "Poverty rate",
  remoteWorkCommonTitle: "Remote-work common",
  remoteWorkDetailFormat: "%@ of workers report working from home.",
  remoteWorkLessCommonTitle: "Remote-work less common",
};

const translations: Record<string, Partial<InsightStrings>> = {
  ar: {
    averageHouseholdSizeTitle: "متوسط حجم الأسرة",
    highQualifier: "(مرتفع)",
    higherPovertyRateTitle: "معدل فقر أعلى",
    housingSnapshotTitle: "لمحة سكنية",
    homeownershipFormat: "نسبة تملك المنازل %@ مع متوسط حجم أسرة %@",
    lowerPovertyRateTitle: "معدل فقر أقل",
    medianGrossRentFormat: "الإيجار الإجمالي الوسيط: %@",
    medianGrossRentHighFormat: "الإيجار الإجمالي الوسيط: %@ %@",
    medianHomeValueFormat: "قيمة المنزل الوسيطة: %@",
    medianHomeValueHighFormat: "قيمة المنزل الوسيطة: %@ %@",
    ownerOccupiedFormat: "%@ سكن يملكه القاطنون، %@ سكن مؤجر",
    peoplePerHouseholdFormat: "%@ أشخاص لكل أسرة.",
    povertyRateDetailFormat: "%@ من السكان تحت خط الفقر (تقدير ACS).",
    povertyRateTitle: "معدل الفقر",
    remoteWorkCommonTitle: "العمل عن بُعد شائع",
    remoteWorkDetailFormat: "%@ من العاملين أفادوا بأنهم يعملون من المنزل.",
    remoteWorkLessCommonTitle: "العمل عن بُعد أقل شيوعًا",
  },
  de: {
    averageHouseholdSizeTitle: "Durchschnittliche Haushaltsgröße",
    highQualifier: "(hoch)",
    higherPovertyRateTitle: "Höhere Armutsquote",
    housingSnapshotTitle: "Wohnungsüberblick",
    homeownershipFormat: "Wohneigentum bei %@ mit einer durchschnittlichen Haushaltsgröße von %@",
    lowerPovertyRateTitle: "Niedrigere Armutsquote",
    medianGrossRentFormat: "Median der Bruttomiete: %@",
    medianGrossRentHighFormat: "Median der Bruttomiete: %@ %@",
    medianHomeValueFormat: "Medianer Hauswert: %@",
    medianHomeValueHighFormat: "Medianer Hauswert: %@ %@",
    ownerOccupiedFormat: "%@ eigengenutzt, %@ gemietet",
    peoplePerHouseholdFormat: "%@ Personen pro Haushalt.",
    povertyRateDetailFormat: "%@ der Menschen leben unterhalb der Armutsgrenze (ACS-Schätzung).",
    povertyRateTitle: "Armutsquote",
    remoteWorkCommonTitle: "Remote-Arbeit verbreitet",
    remoteWorkDetailFormat: "%@ der Erwerbstätigen geben an, von zu Hause aus zu arbeiten.",
    remoteWorkLessCommonTitle: "Remote-Arbeit weniger verbreitet",
  },
  es: {
    averageHouseholdSizeTitle: "Tamaño promedio del hogar",
    highQualifier: "(alto)",
    higherPovertyRateTitle: "Mayor tasa de pobreza",
    housingSnapshotTitle: "Resumen de vivienda",
    homeownershipFormat: "Propiedad de vivienda en %@ con un tamaño promedio del hogar de %@",
    lowerPovertyRateTitle: "Menor tasa de pobreza",
    medianGrossRentFormat: "Alquiler bruto mediano: %@",
    medianGrossRentHighFormat: "Alquiler bruto mediano: %@ %@",
    medianHomeValueFormat: "Valor mediano de la vivienda: %@",
    medianHomeValueHighFormat: "Valor mediano de la vivienda: %@ %@",
    ownerOccupiedFormat: "%@ ocupadas por propietarios, %@ ocupadas por inquilinos",
    peoplePerHouseholdFormat: "%@ personas por hogar.",
    povertyRateDetailFormat: "%@ de las personas están por debajo de la línea de pobreza (estimación ACS).",
    povertyRateTitle: "Tasa de pobreza",
    remoteWorkCommonTitle: "Trabajo remoto común",
    remoteWorkDetailFormat: "%@ de los trabajadores informan que trabajan desde casa.",
    remoteWorkLessCommonTitle: "Trabajo remoto menos común",
  },
  "es-419": {
    averageHouseholdSizeTitle: "Tamaño promedio del hogar",
    highQualifier: "(alto)",
    higherPovertyRateTitle: "Mayor tasa de pobreza",
    housingSnapshotTitle: "Resumen de vivienda",
    homeownershipFormat: "Propiedad de vivienda en %@ con un tamaño promedio del hogar de %@",
    lowerPovertyRateTitle: "Menor tasa de pobreza",
    medianGrossRentFormat: "Alquiler bruto mediano: %@",
    medianGrossRentHighFormat: "Alquiler bruto mediano: %@ %@",
    medianHomeValueFormat: "Valor mediano de la vivienda: %@",
    medianHomeValueHighFormat: "Valor mediano de la vivienda: %@ %@",
    ownerOccupiedFormat: "%@ ocupadas por propietarios, %@ ocupadas por inquilinos",
    peoplePerHouseholdFormat: "%@ personas por hogar.",
    povertyRateDetailFormat: "%@ de las personas están por debajo de la línea de pobreza (estimación ACS).",
    povertyRateTitle: "Tasa de pobreza",
    remoteWorkCommonTitle: "Trabajo remoto común",
    remoteWorkDetailFormat: "%@ de los trabajadores informan que trabajan desde casa.",
    remoteWorkLessCommonTitle: "Trabajo remoto menos común",
  },
  fr: {
    averageHouseholdSizeTitle: "Taille moyenne des foyers",
    highQualifier: "(élevé)",
    higherPovertyRateTitle: "Taux de pauvreté plus élevé",
    housingSnapshotTitle: "Aperçu du logement",
    homeownershipFormat: "Accession à la propriété à %@ avec une taille moyenne des foyers de %@",
    lowerPovertyRateTitle: "Taux de pauvreté plus faible",
    medianGrossRentFormat: "Loyer brut médian : %@",
    medianGrossRentHighFormat: "Loyer brut médian : %@ %@",
    medianHomeValueFormat: "Valeur médiane du logement : %@",
    medianHomeValueHighFormat: "Valeur médiane du logement : %@ %@",
    ownerOccupiedFormat: "%@ occupés par leur propriétaire, %@ occupés par des locataires",
    peoplePerHouseholdFormat: "%@ personnes par foyer.",
    povertyRateDetailFormat: "%@ des habitants vivent sous le seuil de pauvreté (estimation ACS).",
    povertyRateTitle: "Taux de pauvreté",
    remoteWorkCommonTitle: "Télétravail courant",
    remoteWorkDetailFormat: "%@ des travailleurs déclarent travailler depuis chez eux.",
    remoteWorkLessCommonTitle: "Télétravail moins courant",
  },
  "fr-CA": {
    averageHouseholdSizeTitle: "Taille moyenne des foyers",
    highQualifier: "(élevé)",
    higherPovertyRateTitle: "Taux de pauvreté plus élevé",
    housingSnapshotTitle: "Aperçu du logement",
    homeownershipFormat: "Accession à la propriété à %@ avec une taille moyenne des foyers de %@",
    lowerPovertyRateTitle: "Taux de pauvreté plus faible",
    medianGrossRentFormat: "Loyer brut médian : %@",
    medianGrossRentHighFormat: "Loyer brut médian : %@ %@",
    medianHomeValueFormat: "Valeur médiane du logement : %@",
    medianHomeValueHighFormat: "Valeur médiane du logement : %@ %@",
    ownerOccupiedFormat: "%@ occupés par leur propriétaire, %@ occupés par des locataires",
    peoplePerHouseholdFormat: "%@ personnes par foyer.",
    povertyRateDetailFormat: "%@ des habitants vivent sous le seuil de pauvreté (estimation ACS).",
    povertyRateTitle: "Taux de pauvreté",
    remoteWorkCommonTitle: "Télétravail courant",
    remoteWorkDetailFormat: "%@ des travailleurs déclarent travailler depuis chez eux.",
    remoteWorkLessCommonTitle: "Télétravail moins courant",
  },
  ja: {
    averageHouseholdSizeTitle: "平均世帯人数",
    highQualifier: "（高い）",
    higherPovertyRateTitle: "貧困率が高い",
    housingSnapshotTitle: "住宅スナップショット",
    homeownershipFormat: "持ち家率は %@、平均世帯人数は %@ です",
    lowerPovertyRateTitle: "貧困率が低い",
    medianGrossRentFormat: "総家賃中央値: %@",
    medianGrossRentHighFormat: "総家賃中央値: %@ %@",
    medianHomeValueFormat: "住宅価値中央値: %@",
    medianHomeValueHighFormat: "住宅価値中央値: %@ %@",
    ownerOccupiedFormat: "%@ が持ち家、%@ が賃貸",
    peoplePerHouseholdFormat: "1 世帯あたり %@ 人。",
    povertyRateDetailFormat: "%@ の人が貧困線以下で暮らしています（ACS 推計）。",
    povertyRateTitle: "貧困率",
    remoteWorkCommonTitle: "在宅勤務が多い",
    remoteWorkDetailFormat: "%@ の就業者が在宅勤務をしていると回答しています。",
    remoteWorkLessCommonTitle: "在宅勤務が少ない",
  },
  ko: {
    averageHouseholdSizeTitle: "평균 가구원 수",
    highQualifier: "(높음)",
    higherPovertyRateTitle: "높은 빈곤율",
    housingSnapshotTitle: "주거 스냅샷",
    homeownershipFormat: "자가 보유 비율은 %@이고 평균 가구원 수는 %@입니다",
    lowerPovertyRateTitle: "낮은 빈곤율",
    medianGrossRentFormat: "중위 총임대료: %@",
    medianGrossRentHighFormat: "중위 총임대료: %@ %@",
    medianHomeValueFormat: "중위 주택 가치: %@",
    medianHomeValueHighFormat: "중위 주택 가치: %@ %@",
    ownerOccupiedFormat: "%@ 자가 거주, %@ 임차 거주",
    peoplePerHouseholdFormat: "가구당 %@명.",
    povertyRateDetailFormat: "%@의 인구가 빈곤선 이하에 있습니다(ACS 추정치).",
    povertyRateTitle: "빈곤율",
    remoteWorkCommonTitle: "재택근무 비중 높음",
    remoteWorkDetailFormat: "%@의 근로자가 재택근무를 한다고 응답했습니다.",
    remoteWorkLessCommonTitle: "재택근무 비중 낮음",
  },
  "pt-BR": {
    averageHouseholdSizeTitle: "Tamanho médio do domicílio",
    highQualifier: "(alto)",
    higherPovertyRateTitle: "Maior taxa de pobreza",
    housingSnapshotTitle: "Resumo de moradia",
    homeownershipFormat: "Taxa de propriedade de %@ com tamanho médio do domicílio de %@",
    lowerPovertyRateTitle: "Menor taxa de pobreza",
    medianGrossRentFormat: "Aluguel bruto mediano: %@",
    medianGrossRentHighFormat: "Aluguel bruto mediano: %@ %@",
    medianHomeValueFormat: "Valor mediano da casa: %@",
    medianHomeValueHighFormat: "Valor mediano da casa: %@ %@",
    ownerOccupiedFormat: "%@ ocupados por proprietários, %@ ocupados por inquilinos",
    peoplePerHouseholdFormat: "%@ pessoas por domicílio.",
    povertyRateDetailFormat: "%@ das pessoas estão abaixo da linha da pobreza (estimativa ACS).",
    povertyRateTitle: "Taxa de pobreza",
    remoteWorkCommonTitle: "Trabalho remoto comum",
    remoteWorkDetailFormat: "%@ dos trabalhadores informam que trabalham de casa.",
    remoteWorkLessCommonTitle: "Trabalho remoto menos comum",
  },
  "pt-PT": {
    averageHouseholdSizeTitle: "Tamanho médio do domicílio",
    highQualifier: "(alto)",
    higherPovertyRateTitle: "Maior taxa de pobreza",
    housingSnapshotTitle: "Resumo de moradia",
    homeownershipFormat: "Taxa de propriedade de %@ com tamanho médio do domicílio de %@",
    lowerPovertyRateTitle: "Menor taxa de pobreza",
    medianGrossRentFormat: "Aluguel bruto mediano: %@",
    medianGrossRentHighFormat: "Aluguel bruto mediano: %@ %@",
    medianHomeValueFormat: "Valor mediano da casa: %@",
    medianHomeValueHighFormat: "Valor mediano da casa: %@ %@",
    ownerOccupiedFormat: "%@ ocupados por proprietários, %@ ocupados por inquilinos",
    peoplePerHouseholdFormat: "%@ pessoas por domicílio.",
    povertyRateDetailFormat: "%@ das pessoas estão abaixo da linha da pobreza (estimativa ACS).",
    povertyRateTitle: "Taxa de pobreza",
    remoteWorkCommonTitle: "Trabalho remoto comum",
    remoteWorkDetailFormat: "%@ dos trabalhadores informam que trabalham de casa.",
    remoteWorkLessCommonTitle: "Trabalho remoto menos comum",
  },
  tr: {
    averageHouseholdSizeTitle: "Ortalama hane büyüklüğü",
    highQualifier: "(yüksek)",
    higherPovertyRateTitle: "Daha yüksek yoksulluk oranı",
    housingSnapshotTitle: "Konut özeti",
    homeownershipFormat: "Konut sahipliği %@, ortalama hane büyüklüğü %@",
    lowerPovertyRateTitle: "Daha düşük yoksulluk oranı",
    medianGrossRentFormat: "Medyan brüt kira: %@",
    medianGrossRentHighFormat: "Medyan brüt kira: %@ %@",
    medianHomeValueFormat: "Medyan ev değeri: %@",
    medianHomeValueHighFormat: "Medyan ev değeri: %@ %@",
    ownerOccupiedFormat: "%@ ev sahibi oturumlu, %@ kiracı oturumlu",
    peoplePerHouseholdFormat: "Hane başına %@ kişi.",
    povertyRateDetailFormat: "İnsanların %@ kadarı yoksulluk sınırının altında yaşıyor (ACS tahmini).",
    povertyRateTitle: "Yoksulluk oranı",
    remoteWorkCommonTitle: "Uzaktan çalışma yaygın",
    remoteWorkDetailFormat: "Çalışanların %@ kadarı evden çalıştığını bildiriyor.",
    remoteWorkLessCommonTitle: "Uzaktan çalışma daha az yaygın",
  },
  vi: {
    averageHouseholdSizeTitle: "Quy mô hộ trung bình",
    highQualifier: "(cao)",
    higherPovertyRateTitle: "Tỷ lệ nghèo cao hơn",
    housingSnapshotTitle: "Tóm tắt nhà ở",
    homeownershipFormat: "Tỷ lệ sở hữu nhà là %@ với quy mô hộ trung bình %@",
    lowerPovertyRateTitle: "Tỷ lệ nghèo thấp hơn",
    medianGrossRentFormat: "Tiền thuê gộp trung vị: %@",
    medianGrossRentHighFormat: "Tiền thuê gộp trung vị: %@ %@",
    medianHomeValueFormat: "Giá trị nhà trung vị: %@",
    medianHomeValueHighFormat: "Giá trị nhà trung vị: %@ %@",
    ownerOccupiedFormat: "%@ nhà ở do chủ sở hữu ở, %@ nhà ở do người thuê ở",
    peoplePerHouseholdFormat: "%@ người mỗi hộ.",
    povertyRateDetailFormat: "%@ dân số ở dưới ngưỡng nghèo (ước tính ACS).",
    povertyRateTitle: "Tỷ lệ nghèo",
    remoteWorkCommonTitle: "Làm việc từ xa phổ biến",
    remoteWorkDetailFormat: "%@ người lao động cho biết họ làm việc tại nhà.",
    remoteWorkLessCommonTitle: "Làm việc từ xa ít phổ biến hơn",
  },
  "zh-Hans": {
    averageHouseholdSizeTitle: "平均家庭规模",
    highQualifier: "（高）",
    higherPovertyRateTitle: "较高贫困率",
    housingSnapshotTitle: "住房概览",
    homeownershipFormat: "自有住房占比为 %@，平均家庭规模为 %@",
    lowerPovertyRateTitle: "较低贫困率",
    medianGrossRentFormat: "总租金中位数：%@",
    medianGrossRentHighFormat: "总租金中位数：%@ %@",
    medianHomeValueFormat: "房屋价值中位数：%@",
    medianHomeValueHighFormat: "房屋价值中位数：%@ %@",
    ownerOccupiedFormat: "%@ 为自住房，%@ 为租住",
    peoplePerHouseholdFormat: "每户 %@ 人。",
    povertyRateDetailFormat: "%@ 的人口低于贫困线（ACS 估算）。",
    povertyRateTitle: "贫困率",
    remoteWorkCommonTitle: "远程办公较常见",
    remoteWorkDetailFormat: "%@ 的劳动者表示在家工作。",
    remoteWorkLessCommonTitle: "远程办公较少见",
  },
  "zh-Hant": {
    averageHouseholdSizeTitle: "平均家庭規模",
    highQualifier: "（高）",
    higherPovertyRateTitle: "較高貧困率",
    housingSnapshotTitle: "住房概覽",
    homeownershipFormat: "自有住房占比為 %@，平均家庭規模為 %@",
    lowerPovertyRateTitle: "較低貧困率",
    medianGrossRentFormat: "總租金中位數：%@",
    medianGrossRentHighFormat: "總租金中位數：%@ %@",
    medianHomeValueFormat: "房屋價值中位數：%@",
    medianHomeValueHighFormat: "房屋價值中位數：%@ %@",
    ownerOccupiedFormat: "%@ 為自住房，%@ 為租住",
    peoplePerHouseholdFormat: "每戶 %@ 人。",
    povertyRateDetailFormat: "%@ 的人口低於貧困線（ACS 估算）。",
    povertyRateTitle: "貧困率",
    remoteWorkCommonTitle: "遠端工作較常見",
    remoteWorkDetailFormat: "%@ 的勞動者表示在家工作。",
    remoteWorkLessCommonTitle: "遠端工作較少見",
  },
  "zh-HK": {
    averageHouseholdSizeTitle: "平均家庭規模",
    highQualifier: "（高）",
    higherPovertyRateTitle: "較高貧困率",
    housingSnapshotTitle: "住房概覽",
    homeownershipFormat: "自有住房占比為 %@，平均家庭規模為 %@",
    lowerPovertyRateTitle: "較低貧困率",
    medianGrossRentFormat: "總租金中位數：%@",
    medianGrossRentHighFormat: "總租金中位數：%@ %@",
    medianHomeValueFormat: "房屋價值中位數：%@",
    medianHomeValueHighFormat: "房屋價值中位數：%@ %@",
    ownerOccupiedFormat: "%@ 為自住房，%@ 為租住",
    peoplePerHouseholdFormat: "每戶 %@ 人。",
    povertyRateDetailFormat: "%@ 的人口低於貧困線（ACS 估算）。",
    povertyRateTitle: "貧困率",
    remoteWorkCommonTitle: "遠端工作較常見",
    remoteWorkDetailFormat: "%@ 的勞動者表示在家工作。",
    remoteWorkLessCommonTitle: "遠端工作較少見",
  },
};

export function makeNeighborhoodInsights(
  demographics: Demographics,
  locale: string | null
): InsightResponse[] {
  const strings = insightStringsFor(locale);
  const insights: InsightResponse[] = [];
  const housingDetails: string[] = [];
  let housingSeverity: InsightSeverity = "neutral";

  if (typeof demographics.medianHomeValue === "number") {
    const qualifier = demographics.medianHomeValue >= 1_000_000 ? strings.highQualifier : "";
    housingDetails.push(
      qualifier.length > 0
        ? interpolate(strings.medianHomeValueHighFormat, [
            currencyString(demographics.medianHomeValue, locale),
            qualifier,
          ])
        : interpolate(strings.medianHomeValueFormat, [
            currencyString(demographics.medianHomeValue, locale),
          ])
    );
    if (demographics.medianHomeValue >= 1_000_000) {
      housingSeverity = "caution";
    }
  }

  if (typeof demographics.medianGrossRent === "number") {
    const qualifier = demographics.medianGrossRent >= 3000 ? strings.highQualifier : "";
    housingDetails.push(
      qualifier.length > 0
        ? interpolate(strings.medianGrossRentHighFormat, [
            currencyString(demographics.medianGrossRent, locale),
            qualifier,
          ])
        : interpolate(strings.medianGrossRentFormat, [
            currencyString(demographics.medianGrossRent, locale),
          ])
    );
    if (demographics.medianGrossRent >= 3000) {
      housingSeverity = "caution";
    }
  }

  if (
    typeof demographics.ownerOccupiedPct === "number" &&
    typeof demographics.renterOccupiedPct === "number"
  ) {
    housingDetails.push(
      interpolate(strings.ownerOccupiedFormat, [
        percentString(demographics.ownerOccupiedPct, locale),
        percentString(demographics.renterOccupiedPct, locale),
      ])
    );
    if (housingSeverity !== "caution" && demographics.ownerOccupiedPct >= 60) {
      housingSeverity = "positive";
    }
  }

  if (
    typeof demographics.ownerOccupiedPct === "number" &&
    typeof demographics.averageHouseholdSize === "number"
  ) {
    housingDetails.push(
      interpolate(strings.homeownershipFormat, [
        percentString(demographics.ownerOccupiedPct, locale),
        decimalString(demographics.averageHouseholdSize, locale, 1),
      ])
    );
  }

  if (housingDetails.length > 0) {
    insights.push({
      category: "housing",
      severity: housingSeverity,
      title: strings.housingSnapshotTitle,
      detail: `${housingDetails.join(". ")}.`,
    });
  }

  if (typeof demographics.averageHouseholdSize === "number") {
    insights.push({
      category: "demographics",
      severity: "neutral",
      title: strings.averageHouseholdSizeTitle,
      detail: interpolate(strings.peoplePerHouseholdFormat, [
        decimalString(demographics.averageHouseholdSize, locale, 2),
      ]),
    });
  }

  if (typeof demographics.workersWfhPct === "number") {
    const isCommon = demographics.workersWfhPct >= 20;
    insights.push({
      category: "mobility",
      severity: isCommon ? "positive" : "neutral",
      title: isCommon ? strings.remoteWorkCommonTitle : strings.remoteWorkLessCommonTitle,
      detail: interpolate(strings.remoteWorkDetailFormat, [
        percentString(demographics.workersWfhPct, locale),
      ]),
    });
  }

  if (typeof demographics.povertyRatePct === "number") {
    let severity: InsightSeverity = "neutral";
    let title = strings.povertyRateTitle;

    if (demographics.povertyRatePct >= 20) {
      severity = "caution";
      title = strings.higherPovertyRateTitle;
    } else if (demographics.povertyRatePct <= 8) {
      severity = "positive";
      title = strings.lowerPovertyRateTitle;
    }

    insights.push({
      category: "affordability",
      severity,
      title,
      detail: interpolate(strings.povertyRateDetailFormat, [
        percentString(demographics.povertyRatePct, locale),
      ]),
    });
  }

  return insights;
}

function insightStringsFor(locale: string | null): InsightStrings {
  const normalized = normalizeLocale(locale);
  return {
    ...en,
    ...(translations[normalized] ?? {}),
  };
}

function normalizeLocale(locale: string | null): string {
  if (!locale) {
    return "en";
  }

  const trimmed = locale.replace(/_/g, "-");
  const lower = trimmed.toLowerCase();

  if (lower.startsWith("zh-hk")) return "zh-HK";
  if (lower.includes("hant")) return "zh-Hant";
  if (lower.includes("hans")) return "zh-Hans";
  if (lower.startsWith("zh")) return "zh-Hans";
  if (lower.startsWith("fr-ca")) return "fr-CA";
  if (lower.startsWith("fr")) return "fr";
  if (lower.startsWith("pt-br")) return "pt-BR";
  if (lower.startsWith("pt")) return "pt-PT";
  if (lower.startsWith("es-419")) return "es-419";
  if (lower.startsWith("es-es")) return "es";
  if (lower.startsWith("es")) return "es-419";
  if (lower.startsWith("ar")) return "ar";
  if (lower.startsWith("de")) return "de";
  if (lower.startsWith("ja")) return "ja";
  if (lower.startsWith("ko")) return "ko";
  if (lower.startsWith("tr")) return "tr";
  if (lower.startsWith("vi")) return "vi";

  return "en";
}

function interpolate(format: string, values: string[]): string {
  let index = 0;
  return format.replace(/%@/g, () => values[index++] ?? "");
}

function percentString(value: number, locale: string | null): string {
  return `${decimalString(value, locale, 0)}%`;
}

function decimalString(value: number, locale: string | null, maximumFractionDigits: number): string {
  return new Intl.NumberFormat(locale ?? undefined, {
    minimumFractionDigits: maximumFractionDigits,
    maximumFractionDigits,
  }).format(value);
}

function currencyString(value: number, locale: string | null): string {
  return new Intl.NumberFormat(locale ?? undefined, {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0,
  }).format(value);
}
