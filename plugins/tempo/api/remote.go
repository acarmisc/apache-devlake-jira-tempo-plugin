/*
Licensed to the Apache Software Foundation (ASF) under one or more
contributor license agreements.  See the NOTICE file distributed with
this work for additional information regarding copyright ownership.
The ASF licenses this file to You under the Apache License, Version 2.0
(the "License"); you may not use this file except in compliance with
the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package api

import (
	"github.com/apache/incubator-devlake/core/errors"
	"github.com/apache/incubator-devlake/core/plugin"
	"github.com/apache/incubator-devlake/helpers/pluginhelper/api"
	dsmodels "github.com/apache/incubator-devlake/helpers/pluginhelper/api/models"
	"github.com/apache/incubator-devlake/plugins/tempo/models"
)

type TempoRemotePagination struct {
	Limit  int `json:"limit" mapstructure:"limit"`
	Offset int `json:"offset" mapstructure:"offset"`
}

func listTempoRemoteTeams(
	_ *models.TempoConnection,
	apiClient plugin.ApiClient,
	groupId string,
	page TempoRemotePagination,
) (
	children []dsmodels.DsRemoteApiScopeListEntry[models.TempoTeam],
	nextPage *TempoRemotePagination,
	err errors.Error,
) {
	if page.Limit == 0 {
		page.Limit = 50
	}
	
	// Fetch teams from Tempo API
	res, err := apiClient.Get("teams", nil, nil)
	if err != nil {
		return nil, nil, errors.Default.Wrap(err, "failed to get teams from Tempo API")
	}
	
	var teams []models.TempoTeamResponse
	err = api.UnmarshalResponse(res, &teams)
	if err != nil {
		return nil, nil, errors.Default.Wrap(err, "failed to unmarshal teams response")
	}
	
	// Apply pagination
	start := page.Offset
	end := start + page.Limit
	if start >= len(teams) {
		return nil, nil, nil
	}
	if end > len(teams) {
		end = len(teams)
	}
	
	pagedTeams := teams[start:end]
	for _, team := range pagedTeams {
		children = append(children, dsmodels.DsRemoteApiScopeListEntry[models.TempoTeam]{
			Type:     api.RAS_ENTRY_TYPE_SCOPE,
			Id:       team.Id,
			ParentId: nil,
			Name:     team.Name,
			FullName: team.Name,
			Data:     team.ConvertToToolLayer(0),
		})
	}
	
	// Check if there are more pages
	if end < len(teams) {
		nextPage = &TempoRemotePagination{
			Limit:  page.Limit,
			Offset: page.Offset + page.Limit,
		}
	}
	
	return children, nextPage, nil
}

// RemoteScopes list all available scopes on the remote server
// @Summary list all available scopes on the remote server
// @Description list all available scopes on the remote server
// @Accept application/json
// @Param connectionId path int false "connection ID"
// @Param groupId query string false "group ID"
// @Param pageToken query string false "page Token"
// @Failure 400  {object} shared.ApiBody "Bad Request"
// @Failure 500  {object} shared.ApiBody "Internal Error"
// @Success 200  {object} dsmodels.DsRemoteApiScopeList[models.TempoTeam]
// @Tags plugins/tempo
// @Router /plugins/tempo/connections/{connectionId}/remote-scopes [GET]
func RemoteScopes(input *plugin.ApiResourceInput) (*plugin.ApiResourceOutput, errors.Error) {
	return raScopeList.Get(input)
}

func searchTempoRemoteTeams(
	apiClient plugin.ApiClient,
	params *dsmodels.DsRemoteApiScopeSearchParams,
) (
	children []dsmodels.DsRemoteApiScopeListEntry[models.TempoTeam],
	err errors.Error,
) {
	// Fetch all teams
	res, err := apiClient.Get("teams", nil, nil)
	if err != nil {
		return nil, errors.Default.Wrap(err, "failed to get teams from Tempo API")
	}
	
	var teams []models.TempoTeamResponse
	err = api.UnmarshalResponse(res, &teams)
	if err != nil {
		return nil, errors.Default.Wrap(err, "failed to unmarshal teams response")
	}
	
	// Filter by search term
	search := params.Search
	for _, team := range teams {
		if search == "" || containsIgnoreCase(team.Name, search) {
			children = append(children, dsmodels.DsRemoteApiScopeListEntry[models.TempoTeam]{
				Type:     api.RAS_ENTRY_TYPE_SCOPE,
				Id:       team.Id,
				ParentId: nil,
				Name:     team.Name,
				FullName: team.Name,
				Data:     team.ConvertToToolLayer(0),
			})
		}
	}
	
	// Apply pagination
	start := (params.Page - 1) * params.PageSize
	end := start + params.PageSize
	if start >= len(children) {
		return nil, nil
	}
	if end > len(children) {
		end = len(children)
	}
	
	return children[start:end], nil
}

// SearchRemoteScopes searches scopes on the remote server
// @Summary searches scopes on the remote server
// @Description searches scopes on the remote server
// @Accept application/json
// @Param connectionId path int false "connection ID"
// @Param search query string false "search"
// @Param page query int false "page number"
// @Param pageSize query int false "page size per page"
// @Failure 400  {object} shared.ApiBody "Bad Request"
// @Failure 500  {object} shared.ApiBody "Internal Error"
// @Success 200  {object} dsmodels.DsRemoteApiScopeList[models.TempoTeam] "the parentIds are always null"
// @Tags plugins/tempo
// @Router /plugins/tempo/connections/{connectionId}/search-remote-scopes [GET]
func SearchRemoteScopes(input *plugin.ApiResourceInput) (*plugin.ApiResourceOutput, errors.Error) {
	return raScopeSearch.Get(input)
}

// Proxy forward API requests to Tempo API
// @Summary Remote server API proxy
// @Description Forward API requests to the specified remote server
// @Param connectionId path int true "connection ID"
// @Param path path string true "path to a API endpoint"
// @Router /plugins/tempo/connections/{connectionId}/proxy/{path} [GET]
// @Tags plugins/tempo
func Proxy(input *plugin.ApiResourceInput) (*plugin.ApiResourceOutput, errors.Error) {
	return raProxy.Proxy(input)
}

func containsIgnoreCase(s, substr string) bool {
	s = toLower(s)
	substr = toLower(substr)
	return contains(s, substr)
}

func toLower(s string) string {
	result := make([]byte, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'A' && c <= 'Z' {
			c += 'a' - 'A'
		}
		result[i] = c
	}
	return string(result)
}

func contains(s, substr string) bool {
	if len(substr) == 0 {
		return true
	}
	if len(s) < len(substr) {
		return false
	}
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
