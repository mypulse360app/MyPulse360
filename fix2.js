const fs = require('fs');
let content = fs.readFileSync('lib/features/health_dashboard/presentation/pages/dashboard_page.dart', 'utf-8');
content = content.replace(/\[^C]*C/, '\°C');
content = content.replace(/\[^\w]*via/, '\ • via');
content = content.replace(/}\{item.form\}[^\w]*\{item.quantity\}/, '}{item.form} • {item.quantity}');
fs.writeFileSync('lib/features/health_dashboard/presentation/pages/dashboard_page.dart', content, 'utf-8');
console.log('Fixed completely');
