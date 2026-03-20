#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Nov 28 11:04:34 2024

@author: aleksandra urman
"""

#this is a single iteration of the scraper, to run daily we have a cron job set up

import asyncio
from playwright.async_api import async_playwright
import os
import pandas as pd
import random
import time

# Get the current working directory
current_dir = os.getcwd()

#if wrong, set to where it should be
#os.chdir('')


#read in the trends master list (available as part of the released dataset)
df = pd.read_csv('Trends_LocationList.csv', encoding='utf-8')

# Function to scrape data for a specific tag
async def scrape_data(playwright, tag):
    # Launch the browser in non-headless mode
    #for testing purposes, one might want to first run this with headless=False
    browser = await playwright.chromium.launch(headless=True)

    # Define the folder path for the tag
    base_dir = os.getcwd()  # Current working directory
    tag_dir = os.path.join(base_dir, "data", str(tag))
    os.makedirs(tag_dir, exist_ok=True)  # Ensure the directory exists

    # Use the tag directory as the download directory
    context = await browser.new_context(accept_downloads=True)
    page = await context.new_page()

    # Replace 'US' in the URL with the tag value
    url = f"https://trends.google.com/trending?geo={tag}&hours=24"
    await page.goto(url, wait_until="networkidle")
    
    random_sleep = random.randint(1, 5)
    await asyncio.sleep(random_sleep)

    # Interact with the page elements
    await page.locator("button", has_text="Export").click()
    random_sleep = random.randint(1, 5)
    await asyncio.sleep(random_sleep)  # Adjust if less time is sufficient

    # Handle the download using async context manager
    async with page.expect_download() as download_info:
        await page.get_by_role("menuitem", name="Download CSV").click()
    download = await download_info.value

    # Save the downloaded file to the tag directory
    save_path = os.path.join(tag_dir, download.suggested_filename)
    await download.save_as(save_path)

    # Close the context and browser
    await context.close()
    await browser.close()
    print(f"Downloaded data for tag: {tag} into {save_path}")

"""
# FOR TESTS ONLY to iterate through the first 3 tags
async def main():
    async with async_playwright() as playwright:
        # Get the first 3 tags
        first_three_tags = df['tag'][:1]

        # Iterate through these tags and scrape data
        for tag in first_three_tags:
            try:
                await scrape_data(playwright, tag)
            except Exception as e:
                print(f"Error scraping data for tag {tag}: {e}")

"""

# Main function to iterate through tags
async def main():
    async with async_playwright() as playwright:
        for tag in df['tag']:
            try:
                await scrape_data(playwright, tag)
            except Exception as e:
                print(f"Error scraping data for tag {tag}: {e}")


#Some helpers, comment or uncomment if needed
# Measure the total execution time
#start_time = time.time()  # Start timing
#asyncio.run(main())  # Run the main function
#end_time = time.time()  # End timing

# Calculate the total time taken
#total_time = end_time - start_time

# Save the total execution time to a text file in the working directory
#time_file_path = os.path.join(current_dir, "execution_time.txt")
#with open(time_file_path, "w") as time_file:
#    time_file.write(f"Total execution time: {total_time:.2f} seconds\n")

#print(f"Total execution time: {total_time:.2f} seconds. Saved to 'execution_time.txt'.")
