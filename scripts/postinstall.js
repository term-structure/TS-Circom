const fs = require('fs');
const path = require('path');

function replaceInFile(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const newContent = content.replace(/node_modules\/circomlib\//g, 'node_modules/../../circomlib/');
    fs.writeFileSync(filePath, newContent);
}

const dirPath = path.join(__dirname, "..", 'node_modules', 'circom-pairing', 'circuits');
fs.readdirSync(dirPath).forEach(file => {
    const filePath = path.join(dirPath, file);
    if (fs.statSync(filePath).isFile()) {
        replaceInFile(filePath);
    }
});
