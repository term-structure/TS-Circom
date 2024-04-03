var mjAPI = require("mathjax-node");
var fs = require('fs');
mjAPI.config({
    MathJax: {
        // traditional MathJax configuration
    }
});
mjAPI.start();

function latexToSVG(latex) {
    return new Promise((resolve, reject) => {
        mjAPI.typeset({
            math: latex,
            format: "TeX",
            svg: true,
        }, function (data) {
            if (!data.errors) {
                resolve(data.svg);
            } else {
                reject(data.errors);
            }
        });
    });
}

async function main(){
    let md = fs.readFileSync('doc/DOC-raw.md', 'utf8');
    let me_slices = md.split('$$');
    for (var i = 1; i < me_slices.length; i += 2) {
        let latex = me_slices[i];
        let filename = 'images/' + Math.floor(i / 2);
        try {
            const svg = await latexToSVG(latex);
            me_slices[i] = "<p style=\"text-align: center\">" + svg + "</p>";
        } catch (err) {
            console.error(err);
        }
    }
    fs.writeFileSync('DOC.md', me_slices.join("\n"));
}

main();