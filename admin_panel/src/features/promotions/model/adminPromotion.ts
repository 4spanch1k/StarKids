export type AdminPromotion = {
  id: string;
  title: string;
  description: string;
  badgeLabel: string;
  imageUrl: string;
  branchIds: string[];
  ctaLabel: string;
  displayOrder: number;
  isActive: boolean;
  isPublished: boolean;
};

export type AdminPromotionCreatePayload = Omit<AdminPromotion, 'id'>;
export type AdminPromotionUpdatePayload = Partial<AdminPromotionCreatePayload>;
