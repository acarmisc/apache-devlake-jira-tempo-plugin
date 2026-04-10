/*
Licensed to the Apache Software Foundation (ASF) under one or more
contributor license agreements.  See the NOTICE file distributed with
this work for additional information regarding copyright ownership.
The ASF licenses this file to You under the Apache License, Version 2.0
(the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package e2e

import (
	"github.com/apache/incubator-devlake/core/models/domainlayer/ticket"
	"github.com/apache/incubator-devlake/helpers/e2ehelper"
	"github.com/apache/incubator-devlake/plugins/tempo/impl"
	"github.com/apache/incubator-devlake/plugins/tempo/models"
	"github.com/apache/incubator-devlake/plugins/tempo/tasks"
	"testing"
)

func TestWorklogDataFlow(t *testing.T) {
	var plugin impl.Tempo
	dataflowTester := e2ehelper.NewDataFlowTester(t, "tempo", plugin)

	taskData := &tasks.TempoTaskData{
		Options: &tasks.TempoOptions{
			ConnectionId: 1,
		},
	}

	// import raw data table
	dataflowTester.ImportCsvIntoRawTable("./raw_tables/_raw_tempo_worklogs.csv", "_raw_tempo_worklogs")

	// verify worklog extraction
	dataflowTester.FlushTabler(&models.TempoWorklog{})
	dataflowTester.Subtask(tasks.ExtractWorklogsMeta, taskData)
	dataflowTester.VerifyTable(
		models.TempoWorklog{},
		"./snapshot_tables/_tool_tempo_worklogs.csv",
		e2ehelper.ColumnWithRawData(
			"connection_id",
			"tempo_worklog_id",
			"issue_id",
			"time_spent_seconds",
			"billable_seconds",
			"start_date",
			"start_time",
			"description",
			"author_account_id",
			"created_at",
			"updated_at",
		),
	)

	// verify worklog conversion
	dataflowTester.ImportCsvIntoTabler("./snapshot_tables/_tool_tempo_worklogs.csv", &models.TempoWorklog{})
	dataflowTester.FlushTabler(&ticket.IssueWorklog{})
	dataflowTester.Subtask(tasks.ConvertWorklogsMeta, taskData)
	dataflowTester.VerifyTable(
		ticket.IssueWorklog{},
		"./snapshot_tables/issue_worklogs.csv",
		e2ehelper.ColumnWithRawData(
			"id",
			"author_id",
			"time_spent_minutes",
			"logged_date",
			"started_date",
			"issue_id",
		),
	)
}
