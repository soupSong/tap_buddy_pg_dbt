def main():
    print("Hello from tap-buddy-pg-dbt!")


if __name__ == "__main__":
    main()
import pandas as pd
from sqlalchemy import create_engine
import os
from dotenv import load_dotenv
from urllib.parse import quote_plus



def main():

    data_folder = "./data"
    files = os.listdir(data_folder)

    # Load environment variables from .env file
    load_dotenv()

    user = os.getenv("user")
    password = quote_plus(os.getenv("password"))
    host = os.getenv("host")
    dbname = os.getenv("dbname")

    # Creating sqlAlchemy engine
    engine = create_engine(f"postgresql://{user}:{password}@{host}:5432/{dbname}")

    # Print files and folders
    for file in files:
        filename = os.path.splitext(os.path.basename(file))[0]  #Can be used as the table name
        print(filename)
        if file.endswith(".csv"):
            full_path = os.path.join(data_folder, file)
            df = pd.read_csv(full_path)
            # print(df.head())

            try:
                df.to_sql(
                    name=filename,
                    con=engine,
                    if_exists="replace",
                    index=False

                )
                print(f"\nData sent successfully into the table: {filename}")
            except Exception as e:
                print(f"\n❌ An error occurred: {e}")





if __name__ == "__main__":
    main()
