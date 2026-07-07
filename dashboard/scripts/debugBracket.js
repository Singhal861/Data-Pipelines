const fs = require('fs');
const data = JSON.parse(fs.readFileSync('public/data/req_1.json', 'utf8'));
const STAGES = ['Round of 32', 'Round of 16', 'Quarter Final', 'Semi Final', 'Final'];
const posNum = (p) => {
  const m = (p || '').match(/-(\d+)/);
  return m ? parseInt(m[1], 10) : 0;
};
const stageRank = (s) => {
  const i = STAGES.indexOf(s);
  return i >= 0 ? i : STAGES.length;
};
const compare = (a, b) => {
  const sd = stageRank(a.stage) - stageRank(b.stage);
  if (sd !== 0) return sd;
  const pd = posNum(a.feeds_into_position) - posNum(b.feeds_into_position);
  if (pd !== 0) return pd;
  const halfA = a.bracket_half || '';
  const halfB = b.bracket_half || '';
  if (halfA === 'Top' && halfB !== 'Top') return -1;
  if (halfA !== 'Top' && halfB === 'Top') return 1;
  if (halfA === 'Bottom' && halfB !== 'Bottom') return -1;
  if (halfA !== 'Bottom' && halfB === 'Bottom') return 1;
  return posNum(a.bracket_position) - posNum(b.bracket_position);
};
const sortFeeders = (a, b) => {
  const ah = a.bracket_half || '';
  const bh = b.bracket_half || '';
  if (ah === 'Top' && bh === 'Bottom') return -1;
  if (ah === 'Bottom' && bh === 'Top') return 1;
  return posNum(a.bracket_position) - posNum(b.bracket_position);
};
const feedersByParent = new Map();
data.forEach((r) => {
  if (!r.feeds_into_position) return;
  const arr = feedersByParent.get(r.feeds_into_position) || [];
  arr.push(r);
  feedersByParent.set(r.feeds_into_position, arr);
});
feedersByParent.forEach((arr) => arr.sort(sortFeeders));
const slotInfo = (m, side) => {
  const explicitName = side === 'home' ? m.home_team_name || m.home_display_name : m.away_team_name || m.away_display_name;
  const explicitLogo = side === 'home' ? m.home_team_logo : m.away_team_logo;
  if (explicitName && explicitName !== 'TBD' && !explicitName.startsWith('Winner of')) {
    return { name: explicitName, logo: explicitLogo, isPlaceholder: false };
  }
  const feeders = feedersByParent.get(m.bracket_position) || [];
  if (feeders.length > 0) {
    const feeder = feeders[side === 'home' ? 0 : 1];
    if (feeder) {
      if (feeder.match_status === 'Finished' && feeder.winner_team_name) {
        return { name: feeder.winner_team_name, isPlaceholder: false };
      }
      return { name: `Winner of ${feeder.bracket_position}`, isPlaceholder: true };
    }
  }
  if (explicitName && explicitName !== 'TBD') {
    return { name: explicitName, logo: explicitLogo, isPlaceholder: false };
  }
  return { name: 'TBD', logo: null, isPlaceholder: true };
};
for (const stage of STAGES) {
  const list = data.filter((m) => m.stage === stage);
  list.sort(compare);
  console.log('---', stage, '---');
  list.forEach((match, i) => {
    const home = slotInfo(match, 'home');
    const away = slotInfo(match, 'away');
    console.log(i, match.bracket_position, match.match_id, home.name, 'vs', away.name, 'placeholder:', home.isPlaceholder, away.isPlaceholder, 'feeds_into:', match.feeds_into_position, 'half:', match.bracket_half);
  });
  console.log();
}
