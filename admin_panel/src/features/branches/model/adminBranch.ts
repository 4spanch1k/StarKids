export type AdminBranchSummary = {
  id: string;
  slug: string;
  name: string;
  city: string;
  shortLabel: string;
  workingHours: string;
  displayOrder: number;
  isActive: boolean;
};

export type AdminBranchDetail = AdminBranchSummary & {
  address: string;
  description: string;
  phone: string;
  whatsappPhone: string;
  mapUrl: string;
  routeLabel: string;
  parkingHint: string;
  arrivalHint: string;
  heroImageUrl: string;
  galleryImageUrls: string[];
  facilities: string[];
};

export type AdminBranchCreatePayload = {
  slug: string;
  name: string;
  city: string;
  address: string;
  shortLabel: string;
  workingHours: string;
  description: string;
  phone: string;
  whatsappPhone: string;
  mapUrl?: string;
  routeLabel?: string;
  parkingHint?: string;
  arrivalHint?: string;
  heroImageUrl?: string;
  galleryImageUrls: string[];
  facilities: string[];
  displayOrder: number;
  isActive: boolean;
};

export type AdminBranchUpdatePayload = Partial<AdminBranchCreatePayload>;

export type AdminBranchContacts = {
  branchId: string;
  address: string;
  phone: string;
  whatsappPhone: string;
  mapUrl: string;
  routeLabel: string;
  parkingHint: string;
  arrivalHint: string;
};

export type AdminBranchContactsPayload = Omit<AdminBranchContacts, 'branchId'>;

export type AdminBranchGallery = {
  branchId: string;
  heroImageUrl: string;
  galleryImageUrls: string[];
};

export type AdminBranchGalleryPayload = Omit<AdminBranchGallery, 'branchId'>;

export type AdminBranchTariff = {
  id?: string;
  title: string;
  priceLabel: string;
  description: string;
  displayOrder: number;
  isActive: boolean;
};

export type AdminBranchRule = {
  id?: string;
  text: string;
  displayOrder: number;
  isActive: boolean;
};

export type AdminBranchPricesRules = {
  branchId: string;
  introTitle: string;
  introDescription: string;
  birthdayNote: string;
  disclaimer: string;
  visitTariffs: AdminBranchTariff[];
  rules: AdminBranchRule[];
};

export type AdminBranchPricesRulesPayload = Omit<
  AdminBranchPricesRules,
  'branchId'
>;

export type AdminBranchMenuCategory = {
  id?: string;
  key: string;
  title: string;
  displayOrder: number;
  isActive: boolean;
};

export type AdminBranchMenuItem = {
  id?: string;
  title: string;
  priceTenge: number;
  imageUrl: string;
  categoryKey: string;
  displayOrder: number;
  isActive: boolean;
};

export type AdminBranchMenu = {
  branchId: string;
  categories: AdminBranchMenuCategory[];
  items: AdminBranchMenuItem[];
};

export type AdminBranchMenuPayload = Omit<AdminBranchMenu, 'branchId'>;

export type AdminBranchTicketItem = {
  id?: string;
  title: string;
  description: string;
  priceTenge: number;
  badgeLabels: string[];
  displayOrder: number;
  isActive: boolean;
};

export type AdminBranchTicketNote = {
  id?: string;
  text: string;
  displayOrder: number;
  isActive: boolean;
};

export type AdminBranchTickets = {
  branchId: string;
  items: AdminBranchTicketItem[];
  notes: AdminBranchTicketNote[];
};

export type AdminBranchTicketsPayload = Omit<AdminBranchTickets, 'branchId'>;
