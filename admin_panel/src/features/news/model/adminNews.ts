export type AdminNews = {
  id: string;
  title: string;
  imageUrl: string;
  description: string;
  isActive: boolean;
  createdAt: string;
};

export type AdminNewsCreatePayload = Omit<AdminNews, 'id' | 'createdAt'>;
export type AdminNewsUpdatePayload = Partial<AdminNewsCreatePayload>;
