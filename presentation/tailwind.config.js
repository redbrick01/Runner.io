/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          "Inter",
          "Pretendard",
          "ui-sans-serif",
          "system-ui",
          "Apple SD Gothic Neo",
          "Malgun Gothic",
          "sans-serif",
        ],
      },
      boxShadow: {
        glow: "0 0 44px rgba(52, 211, 153, 0.22)",
        "blue-glow": "0 0 52px rgba(34, 211, 238, 0.18)",
      },
    },
  },
  plugins: [],
};
