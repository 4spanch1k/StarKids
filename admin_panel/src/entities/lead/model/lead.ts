export type LeadStatus = 'new' | 'in_progress' | 'won' | 'lost';

export type Lead = {
  id: string;
  type: 'birthday' | 'callback' | 'group';
  branchName: string;
  customerName: string;
  status: LeadStatus;
};

