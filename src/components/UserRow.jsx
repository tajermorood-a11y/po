import React from 'react';
import { View, Text } from 'react-native';
import { COLORS } from '../constants/config';
import Avatar from './Avatar';
import { NameWithBadge } from '../finance';

export default function UserRow({ user, badge, rank, highlighted = false, trailing }) {
  return <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 13, borderRadius: 13, backgroundColor: highlighted ? COLORS.card2 : COLORS.card, borderWidth: 1, borderColor: highlighted ? COLORS.accent : COLORS.border }}>
    <Text style={{ color: rank <= 3 ? COLORS.accent : COLORS.muted, width: 28, fontWeight: '900' }}>#{rank ?? user.rank ?? '—'}</Text>
    <Avatar id={user.avatar_option_id} size={42} />
    <View style={{ flex: 1 }}><NameWithBadge name={user.display_name} badge={badge} /></View>
    {trailing || <Text style={{ color: COLORS.accent, fontWeight: '900' }}>{user.total_points || 0}</Text>}
  </View>;
}
