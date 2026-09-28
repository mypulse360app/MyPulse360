@
const fs = require("fs");
let content = fs.readFileSync("lib/features/health_dashboard/presentation/pages/dashboard_page.dart", "utf-8");
content = content.replace(/\$tempVal[^C]*C/, "$tempVal°C");
content = content.replace(/\$statusText[^v]*via/, "$statusText • via");
content = content.replace(/\}\{item\.form\}[^\{]*\{item\.quantity\}/, "}{item.form} • {item.quantity}");
fs.writeFileSync("lib/features/health_dashboard/presentation/pages/dashboard_page.dart", content, "utf-8");
console.log("Fixed for real");
@
