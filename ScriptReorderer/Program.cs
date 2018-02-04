using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Text.RegularExpressions;

namespace ScriptReorderer
{
    class Program
    {
        static void Main(string[] args)
        {
            string path = @"C:\Users\brian\dev\test_files";

            string previousVersionNo = "17.1.0.4";

            string newVersionNo = "17.2.0.100";

            var versionNumberParts = newVersionNo.Split('.');
            var nextBuildNumber = int.Parse(versionNumberParts.Last());
            
            int nextRevision = int.Parse(newVersionNo.Split('.').Last());

            string[] files = Directory.GetFiles(path);

            Array.Sort(files);
            
            for (int i = 0; i < files.Length; i++)
            {
                string originalFileFullPath = files[i];

                string originalFileName = Path.GetFileName(originalFileFullPath);

                string newFileName = i.ToString("D2") + originalFileName.Substring(2);

                string newFileFullPath = Path.Combine(Path.GetDirectoryName(files[i]), newFileName);

                File.Move(originalFileFullPath, newFileFullPath);

                string newContents = UpdateContents(newFileFullPath, previousVersionNo, newVersionNo);

                File.WriteAllText(Path.Combine(@"C:\Users\brian\dev\test_files\out", newFileName), newContents);

                previousVersionNo = newVersionNo;

                newVersionNo = versionNumberParts[0] + "." + versionNumberParts[1] + "." + versionNumberParts[2] + "." + nextBuildNumber++;
            }
        }

        private static string UpdateContents(string path, string previousBuildNo, string newBuildNo)
        {
            string fileContents = File.ReadAllText(path);

            string newContents = Regex.Replace(fileContents, @"SPOOL\s[0-9]{2}_[0-9]{8}[\w|\/.]+", "SPOOL " + Path.GetFileNameWithoutExtension(path) + ".log");

            string commaSeparatedNewBuildNo = newBuildNo.Replace(".", ",");
            string commaSeparatedOldBuildNo = previousBuildNo.Replace(".", ",");
            string previousBuildNoAndNewBuildNoCommaSeparated = commaSeparatedOldBuildNo  + "," + commaSeparatedNewBuildNo;

            string newCheckDbVersionString = @"CMS_ESM.DB_MAINTENANCE.CHECK_DBVERSION(" + previousBuildNoAndNewBuildNoCommaSeparated + ");";
            newContents = Regex.Replace(newContents, @"CMS_ESM.DB_MAINTENANCE.CHECK_DBVERSION\([\d|\s|,]+\);", newCheckDbVersionString);

            string newUpdateDbVersionString = @"CMS_ESM.DB_MAINTENANCE.UPDATE_DBVERSION("+ commaSeparatedNewBuildNo + ", '" + Path.GetFileName(path) + @"', true)";
            newContents = Regex.Replace(newContents, @"CMS_ESM.DB_MAINTENANCE.UPDATE_DBVERSION\([\w|,|\s|\'|\.]+\);", newUpdateDbVersionString);

            return newContents;
        }
    }
}
