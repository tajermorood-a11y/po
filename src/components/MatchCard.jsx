import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { COLORS } from '../constants/config';
import { S } from '../constants/strings';
import Stepper from './Stepper';
import { OddsBadge, ExpectedPoints } from '../finance';
import { formatDateTime } from '../utils/format';

export default function MatchCard({ match, prediction, values, onChange, onSave, saving, message, open }) {
  const changed = !prediction || prediction.predicted_home !== values.h || prediction.predicted_away !== values.a;
  return <View style={{ backgroundColor: COLORS.card, borderColor: COLORS.border, borderWidth: 1, borderRadius: 16, padding: 14, marginBottom: 12, gap: 10 }}>
    <Text style={{ color: COLORS.muted, textAlign: 'right' }}>{match.league} · {formatDateTime(match)}</Text>
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
      <View style={{ flex: 1, alignItems: 'center' }}><Text style={{ color: COLORS.text, fontWeight: '800' }}>{match.home_team}</Text>{open ? <Stepper value={values.h} onChange={v => onChange('h', v)} /> : null}</View>
      <Text style={{ color: COLORS.muted }}>{S.versus}</Text>
      <View style={{ flex: 1, alignItems: 'center' }}><Text style={{ color: COLORS.text, fontWeight: '800' }}>{match.away_team}</Text>{open ? <Stepper value={values.a} onChange={v => onChange('a', v)} /> : null}</View>
    </View>
    <OddsBadge odds={prediction?.odds_at_prediction || match.odds} />
    {open ? <><ExpectedPoints odds={match.odds} /><TouchableOpacity disabled={!changed || saving} onPress={onSave} style={{ backgroundColor: COLORS.accent, borderRadius: 10, padding: 13, alignItems: 'center', opacity: !changed || saving ? 0.5 : 1 }}><Text style={{ color: COLORS.accentText, fontWeight: '900' }}>{saving ? S.loading : prediction ? S.updatePrediction : S.savePrediction}</Text></TouchableOpacity></> : <Text style={{ color: COLORS.muted, textAlign: 'right' }}>{S.closed}</Text>}
    {message ? <Text style={{ color: COLORS.credit, textAlign: 'center' }}>{message}</Text> : null}
  </View>;
}
