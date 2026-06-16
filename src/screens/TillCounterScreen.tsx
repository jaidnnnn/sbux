import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  TouchableOpacity,
  TextInput,
  StatusBar,
} from 'react-native';
import { colors, spacing, borderRadius, fontSize } from '../constants/theme';
import { Denomination } from '../types';

// Common US denominations
const initialDenominations: Denomination[] = [
  { value: 100, count: 0, type: 'note' },
  { value: 50, count: 0, type: 'note' },
  { value: 20, count: 0, type: 'note' },
  { value: 10, count: 0, type: 'note' },
  { value: 5, count: 0, type: 'note' },
  { value: 1, count: 0, type: 'note' },
  { value: 0.25, count: 0, type: 'coin' },
  { value: 0.10, count: 0, type: 'coin' },
  { value: 0.05, count: 0, type: 'coin' },
  { value: 0.01, count: 0, type: 'coin' },
];

export default function TillCounterScreen() {
  const [denominations, setDenominations] = useState<Denomination[]>(initialDenominations);

  const updateCount = (index: number, count: string) => {
    const newDenominations = [...denominations];
    newDenominations[index].count = parseInt(count) || 0;
    setDenominations(newDenominations);
  };

  const incrementCount = (index: number) => {
    const newDenominations = [...denominations];
    newDenominations[index].count += 1;
    setDenominations(newDenominations);
  };

  const decrementCount = (index: number) => {
    const newDenominations = [...denominations];
    if (newDenominations[index].count > 0) {
      newDenominations[index].count -= 1;
    }
    setDenominations(newDenominations);
  };

  const resetAll = () => {
    setDenominations(initialDenominations);
  };

  const totalAmount = denominations.reduce(
    (sum, denom) => sum + denom.value * denom.count,
    0
  );

  const formatCurrency = (value: number) => {
    return `$${value.toFixed(2)}`;
  };

  const getDenominationLabel = (value: number) => {
    if (value >= 1) return `$${value}`;
    return `${Math.round(value * 100)}¢`;
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor={colors.background} />
      
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Till Counter</Text>
        <TouchableOpacity onPress={resetAll} style={styles.resetButton}>
          <Text style={styles.resetButtonText}>Reset</Text>
        </TouchableOpacity>
      </View>

      {/* Total Display */}
      <View style={styles.totalCard}>
        <Text style={styles.totalLabel}>Total Amount</Text>
        <Text style={styles.totalAmount}>{formatCurrency(totalAmount)}</Text>
      </View>

      {/* Denominations List */}
      <ScrollView style={styles.scrollView} showsVerticalScrollIndicator={false}>
        <View style={styles.denominationsContainer}>
          {denominations.map((denom, index) => (
            <View key={index} style={styles.denominationCard}>
              <View style={styles.denominationInfo}>
                <Text style={styles.denominationValue}>
                  {getDenominationLabel(denom.value)}
                </Text>
                <Text style={styles.denominationType}>
                  {denom.type === 'note' ? 'Bill' : 'Coin'}
                </Text>
              </View>

              <View style={styles.counterContainer}>
                <TouchableOpacity
                  onPress={() => decrementCount(index)}
                  style={styles.counterButton}
                >
                  <Text style={styles.counterButtonText}>−</Text>
                </TouchableOpacity>

                <TextInput
                  style={styles.countInput}
                  value={denom.count.toString()}
                  onChangeText={(text) => updateCount(index, text)}
                  keyboardType="number-pad"
                  maxLength={4}
                />

                <TouchableOpacity
                  onPress={() => incrementCount(index)}
                  style={styles.counterButton}
                >
                  <Text style={styles.counterButtonText}>+</Text>
                </TouchableOpacity>
              </View>

              <Text style={styles.subtotal}>
                {formatCurrency(denom.value * denom.count)}
              </Text>
            </View>
          ))}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  title: {
    fontSize: fontSize.xl,
    fontWeight: '700',
    color: colors.primary,
  },
  resetButton: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  resetButtonText: {
    fontSize: fontSize.md,
    color: colors.accent,
    fontWeight: '600',
  },
  totalCard: {
    backgroundColor: colors.primary,
    marginHorizontal: spacing.lg,
    marginBottom: spacing.lg,
    padding: spacing.lg,
    borderRadius: borderRadius.lg,
    alignItems: 'center',
  },
  totalLabel: {
    fontSize: fontSize.sm,
    color: colors.background,
    opacity: 0.8,
    marginBottom: spacing.xs,
  },
  totalAmount: {
    fontSize: fontSize.xxl,
    fontWeight: '700',
    color: colors.background,
  },
  scrollView: {
    flex: 1,
  },
  denominationsContainer: {
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.xl,
  },
  denominationCard: {
    backgroundColor: colors.card,
    borderRadius: borderRadius.md,
    padding: spacing.md,
    marginBottom: spacing.sm,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    shadowColor: colors.shadow,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  denominationInfo: {
    flex: 1,
  },
  denominationValue: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.text,
    marginBottom: spacing.xs / 2,
  },
  denominationType: {
    fontSize: fontSize.xs,
    color: colors.textLight,
    textTransform: 'uppercase',
  },
  counterContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.sm,
  },
  counterButton: {
    width: 36,
    height: 36,
    borderRadius: borderRadius.sm,
    backgroundColor: colors.border,
    alignItems: 'center',
    justifyContent: 'center',
  },
  counterButtonText: {
    fontSize: fontSize.lg,
    fontWeight: '600',
    color: colors.text,
  },
  countInput: {
    width: 50,
    height: 36,
    marginHorizontal: spacing.sm,
    borderRadius: borderRadius.sm,
    backgroundColor: colors.background,
    textAlign: 'center',
    fontSize: fontSize.md,
    fontWeight: '600',
    color: colors.text,
  },
  subtotal: {
    fontSize: fontSize.md,
    fontWeight: '600',
    color: colors.accent,
    minWidth: 70,
    textAlign: 'right',
  },
});
