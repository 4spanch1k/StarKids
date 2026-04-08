export type AdminFaq = {
  id: string;
  question: string;
  answer: string;
  displayOrder: number;
  isActive: boolean;
  isPublished: boolean;
};

export type AdminFaqCreatePayload = Omit<AdminFaq, 'id'>;
export type AdminFaqUpdatePayload = Partial<AdminFaqCreatePayload>;

export type AdminContentBlock = {
  id: string;
  surface: string;
  key: string;
  title: string;
  body: string;
  ctaLabel: string;
  displayOrder: number;
  isActive: boolean;
  isPublished: boolean;
};

export type AdminContentBlockCreatePayload = Omit<AdminContentBlock, 'id'>;
export type AdminContentBlockUpdatePayload = Partial<AdminContentBlockCreatePayload>;
