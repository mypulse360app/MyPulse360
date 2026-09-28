const fs = require('fs');
let content = fs.readFileSync('lib/features/health_dashboard/presentation/pages/dashboard_page.dart', 'utf-8');
// Fix calendar emoji (which might be mangled as various combinations like Ã°Å¸â€œâ€¦ or ðŸ“…)
content = content.replace(/emoji: '.*',/g, function(match) {
    if (match.includes('Book') || content.substring(content.indexOf(match), content.indexOf(match)+50).includes('Book')) {
        return "emoji: '📅',";
    }
    return match;
});
content = content.replace(/emoji:\s*['"][^'"]*['"]/g, function(match, offset, string) {
    // Look at context to determine which emoji it should be
    let contextStr = string.substring(offset, offset + 150);
    if (contextStr.includes('Book')) return "emoji: '📅'";
    if (contextStr.includes('Prescription')) return "emoji: '💊'";
    return match;
});
// Fix the degree symbol which became 'Ã‚Â°C' or 'Ã,°C' or 'Â°C' or similar.
content = content.replace(/-- [^C]*C/, '-- °C');
content = content.replace(/\[^C]*C/, '\°C');
fs.writeFileSync('lib/features/health_dashboard/presentation/pages/dashboard_page.dart', content, 'utf-8');
console.log('Fixed');
