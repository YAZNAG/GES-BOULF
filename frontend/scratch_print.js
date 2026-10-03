const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ headless: 'new' });
  const page = await browser.newPage();
  
  // Go to POS
  await page.goto('http://localhost:5173/admin/pos', { waitUntil: 'networkidle0' });
  
  // Add an item to cart
  await page.waitForSelector('.pos-grid > div');
  await page.click('.pos-grid > div'); // Click first item
  
  // Wait for it to be added to cart
  await new Promise(resolve => setTimeout(resolve, 500));
  
  // Click confirmer
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button'));
    const confirmBtn = btns.find(b => b.textContent.includes('Confirmer'));
    if (confirmBtn) confirmBtn.click();
  });
  
  // Wait for payment modal
  await new Promise(resolve => setTimeout(resolve, 500));
  
  // Click valider la vente
  await page.evaluate(() => {
    const btns = Array.from(document.querySelectorAll('button'));
    const validBtn = btns.find(b => b.textContent.includes('Valider la vente'));
    if (validBtn) validBtn.click();
  });
  
  // Wait for success modal
  await page.waitForSelector('#printable-invoice', { timeout: 5000 });
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Emulate print media and take screenshot
  await page.emulateMediaType('print');
  await page.screenshot({ path: 'print_preview.png', fullPage: true });
  
  await browser.close();
})();
