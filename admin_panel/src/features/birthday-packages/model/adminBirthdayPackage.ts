export type AdminBirthdayPackageSummary = {
  id: string;
  branchId: string;
  slug: string;
  name: string;
  priceFrom: number;
  priceLabel: string;
  guestCapacityLabel: string;
  imageUrl: string;
  isFeatured: boolean;
  isActive: boolean;
  displayOrder: number;
};

export type AdminBirthdayPackageDetail = AdminBirthdayPackageSummary & {
  description: string;
  highlights: string[];
};

export type AdminBirthdayPackageCreatePayload = {
  branchId: string;
  slug: string;
  name: string;
  priceFrom: number;
  priceLabel: string;
  guestCapacityLabel: string;
  description: string;
  highlights: string[];
  imageUrl?: string;
  isFeatured: boolean;
  isActive: boolean;
  displayOrder: number;
};

export type AdminBirthdayPackageUpdatePayload = Partial<AdminBirthdayPackageCreatePayload>;
