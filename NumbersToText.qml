import QtQuick

// ============================================================
// NUMBERS TO TEXT — shell-wide number → word converter.
// Declared once in ShellRoot; all components reference via
// the global `numbersToText` id.
//
// Usage:  numbersToText.convert(38)  →  "Thirty eight"
//         numbersToText.convert(145) →  "One hundred and forty five"
// Handles 0 – 999 999. Falls back to the numeric string beyond that.
// ============================================================
QtObject {

    function convert(n) {
        n = parseInt(n);
        if (isNaN(n) || n < 0) return "";
        n = Math.floor(n);
        if (n === 0) return "Zero";

        var ones = [
            "", "one", "two", "three", "four", "five", "six", "seven",
            "eight", "nine", "ten", "eleven", "twelve", "thirteen",
            "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"
        ];
        var tens = [
            "", "", "twenty", "thirty", "forty", "fifty",
            "sixty", "seventy", "eighty", "ninety"
        ];

        function below100(num) {
            if (num < 20) return ones[num];
            var t = tens[Math.floor(num / 10)];
            var o = num % 10;
            return o > 0 ? t + " " + ones[o] : t;
        }

        function below1000(num) {
            if (num < 100) return below100(num);
            var h = Math.floor(num / 100);
            var r = num % 100;
            return r > 0
                ? ones[h] + " hundred and " + below100(r)
                : ones[h] + " hundred";
        }

        function below1000000(num) {
            if (num < 1000) return below1000(num);
            var th = Math.floor(num / 1000);
            var r  = num % 1000;
            var result = below1000(th) + " thousand";
            if (r > 0)
                result += (r < 100 ? " and " : " ") + below1000(r);
            return result;
        }

        if (n >= 1000000) return n.toString();

        var result = below1000000(n);
        // Sentence-case: capitalise the first letter only
        return result.charAt(0).toUpperCase() + result.slice(1);
    }
}
