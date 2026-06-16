export interface Denomination {
  value: number;
  count: number;
  type: 'note' | 'coin';
}

export interface CashCount {
  denominations: Denomination[];
  total: number;
  timestamp: Date;
}
